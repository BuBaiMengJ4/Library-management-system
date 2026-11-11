#include "LibraryService.h"

#include "Encryption.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDebug>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QImage>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>
#include <QVariant>
#include <algorithm>
#include <cstring>
#include <limits>

namespace {

constexpr int kDefaultBorrowLimit = 12;
constexpr int kFirstBookNumber = 1000;
constexpr int kSchemaVersion = 2;
constexpr int kPasswordIterations = 100000;
constexpr int kPasswordHashLength = 32;
constexpr int kPasswordSaltLength = 16;
constexpr int kMaxLoginFailures = 5;
constexpr int kLoginLockMinutes = 10;
constexpr qint64 kMaxImageBytes = 5 * 1024 * 1024;

QStringList readLegacyLines(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QByteArray data = file.readAll();
    QString text = QString::fromUtf8(data);
    if (text.contains(QChar(0xFFFD))) {
        text = QString::fromLocal8Bit(data);
    }
    text.replace(QStringLiteral("\r\n"), QStringLiteral("\n"));
    text.replace(QLatin1Char('\r'), QLatin1Char('\n'));
    QStringList lines = text.split(QLatin1Char('\n'));
    while (!lines.isEmpty() && lines.last().trimmed().isEmpty()) {
        lines.removeLast();
    }
    return lines;
}

bool isValidUsername(const QString &name) {
    if (name.isEmpty() || name.size() > 20) {
        return false;
    }
    for (const QChar ch : name) {
        if (ch.isSpace() || ch == QLatin1Char('/') || ch == QLatin1Char('\\')) {
            return false;
        }
    }
    return true;
}

bool ensureWritableDirectory(const QString &path) {
    if (path.isEmpty() || !QDir().mkpath(path)) {
        return false;
    }
    QFile probe(path + QStringLiteral("/.write-test"));
    if (!probe.open(QIODevice::WriteOnly)) {
        return false;
    }
    probe.close();
    probe.remove();
    return true;
}

QByteArray pbkdf2(const QByteArray &password, const QByteArray &salt, int iterations, int length) {
    QMessageAuthenticationCode mac(QCryptographicHash::Sha256);
    mac.setKey(password);
    QByteArray block = salt;
    block.append('\0');
    block.append('\0');
    block.append('\0');
    block.append('\1');
    mac.addData(block);
    QByteArray u = mac.result();
    QByteArray result = u;
    for (int i = 1; i < iterations; ++i) {
        mac.reset();
        mac.addData(u);
        u = mac.result();
        for (int j = 0; j < result.size(); ++j) {
            result[j] = static_cast<char>(result.at(j) ^ u.at(j));
        }
    }
    return result.left(length);
}

QString formatDate(const QDateTime &dateTime) {
    return dateTime.isValid() ? dateTime.toString(QStringLiteral("yyyy-MM-dd HH:mm")) : QString();
}

QString formatDay(const QDateTime &dateTime) {
    return dateTime.isValid() ? dateTime.toString(QStringLiteral("yyyy-MM-dd")) : QString();
}

bool parseBool(const QString &text) {
    return text == QStringLiteral("1") || text.compare(QStringLiteral("true"), Qt::CaseInsensitive) == 0;
}

} // namespace

LibraryService::LibraryService(QObject *parent) : QObject(parent) {
    m_connectionName = QStringLiteral("library_%1")
                               .arg(reinterpret_cast<quintptr>(this), 0, 16);

    QString directory = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (!ensureWritableDirectory(directory)) {
        const QString portable = QCoreApplication::applicationDirPath() + QStringLiteral("/data");
        if (ensureWritableDirectory(portable)) {
            directory = portable;
        } else {
            directory = QDir::tempPath() + QStringLiteral("/LibraryManagementSystem");
            QDir().mkpath(directory);
        }
        qWarning() << "AppData is not writable, using fallback data directory:" << directory;
    }

    m_databasePath = directory + QStringLiteral("/library.db");
    m_keyPath = directory + QStringLiteral("/library.key");
    initializeStorage();
}

LibraryService::~LibraryService() {
    closeDatabase();
}

bool LibraryService::initializeStorage() {
    const bool databaseExists = QFileInfo::exists(m_databasePath);
    QString cryptoError;
    if (!Encryption::instance().init(m_keyPath, databaseExists, &cryptoError)) {
        setStorageError(QStringLiteral("加密存储初始化失败：%1").arg(cryptoError));
        return false;
    }

    if (!openDatabase() || !createSchema() || !loadFromDatabase()) {
        return false;
    }

    if (m_users.isEmpty()) {
        if (m_books.isEmpty() && m_loans.isEmpty()) {
            migrateLegacyTextData();
        }
        ensureDefaultAdmin();
        if (!persistAll()) {
            setStorageError(QStringLiteral("初始化数据库失败：%1").arg(m_lastError));
            return false;
        }
    } else if (indexOfUser(QStringLiteral("Administrator")) < 0) {
        ensureDefaultAdmin();
        if (!persistAll()) {
            setStorageError(QStringLiteral("初始化管理员账户失败：%1").arg(m_lastError));
            return false;
        }
    }

    const int adminIndex = indexOfUser(QStringLiteral("Administrator"));
    m_prefillDefaultAdmin = adminIndex >= 0
            && m_users.at(adminIndex).mustChangePassword
            && verifyPassword(QStringLiteral("114514"),
                              m_users.at(adminIndex).passwordHash,
                              m_users.at(adminIndex).passwordSalt);

    m_storageReady = true;
    emit storageChanged();
    return true;
}

bool LibraryService::openDatabase() {
    if (!QSqlDatabase::isDriverAvailable(QStringLiteral("QSQLITE"))) {
        setStorageError(QStringLiteral("未找到 Qt SQLite 驱动（qsqlite），无法打开数据库"));
        return false;
    }

    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connectionName);
    m_db.setDatabaseName(m_databasePath);
    if (!m_db.open()) {
        setStorageError(QStringLiteral("无法打开数据库 %1：%2")
                                .arg(m_databasePath, m_db.lastError().text()));
        closeDatabase();
        return false;
    }

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA foreign_keys = ON"));
    pragma.exec(QStringLiteral("PRAGMA secure_delete = ON"));
    pragma.exec(QStringLiteral("PRAGMA journal_mode = DELETE"));
    return true;
}

int LibraryService::schemaVersion() {
    QSqlQuery query(m_db);
    if (!query.exec(QStringLiteral("PRAGMA user_version")) || !query.next()) {
        return -1;
    }
    return query.value(0).toInt();
}

bool LibraryService::createSchema() {
    const int version = schemaVersion();
    if (version < 0) {
        setStorageError(QStringLiteral("无法读取数据库版本"));
        return false;
    }

    bool hasUsersTable = false;
    bool hasOldUsers = false;
    QSqlQuery tables(m_db);
    if (tables.exec(QStringLiteral(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"))
        && tables.next()) {
        hasUsersTable = true;
    }
    if (hasUsersTable) {
        QSqlQuery columns(m_db);
        if (columns.exec(QStringLiteral("PRAGMA table_info(users)"))) {
            while (columns.next()) {
                if (columns.value(1).toString() == QStringLiteral("password_enc")) {
                    hasOldUsers = true;
                }
            }
        }
    }

    if (version == kSchemaVersion) {
        return true;
    }
    if (hasOldUsers || version == 1) {
        if (!migrateV1ToV2()) {
            return false;
        }
        return true;
    }

    const QStringList statements = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS users ("
                       "id TEXT PRIMARY KEY NOT NULL,"
                       "username_enc BLOB NOT NULL,"
                       "display_name_enc BLOB NOT NULL,"
                       "password_hash_enc BLOB NOT NULL,"
                       "password_salt_enc BLOB NOT NULL,"
                       "admin_enc BLOB NOT NULL,"
                       "must_change_enc BLOB NOT NULL,"
                       "locked_enc BLOB NOT NULL,"
                       "failed_attempts_enc BLOB NOT NULL,"
                       "lock_until_enc BLOB NOT NULL,"
                       "avatar_enc BLOB NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS books ("
                       "number INTEGER PRIMARY KEY NOT NULL,"
                       "name_enc BLOB NOT NULL,"
                       "author_enc BLOB NOT NULL,"
                       "publisher_enc BLOB NOT NULL,"
                       "place_enc BLOB NOT NULL,"
                       "category_enc BLOB NOT NULL,"
                       "description_enc BLOB NOT NULL,"
                       "cover_enc BLOB NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS loans ("
                       "id INTEGER PRIMARY KEY NOT NULL,"
                       "book_number INTEGER NOT NULL,"
                       "username_enc BLOB NOT NULL,"
                       "borrowed_at_enc BLOB NOT NULL,"
                       "due_at_enc BLOB NOT NULL,"
                       "returned_at_enc BLOB NOT NULL,"
                       "renew_count_enc BLOB NOT NULL,"
                       "manual_unreturned_enc BLOB NOT NULL)"),
    };

    for (const QString &statement : statements) {
        QSqlQuery query(m_db);
        if (!query.exec(statement)) {
            setStorageError(QStringLiteral("创建数据库结构失败：%1").arg(query.lastError().text()));
            return false;
        }
    }

    QSqlQuery versionQuery(m_db);
    versionQuery.exec(QStringLiteral("PRAGMA user_version = %1").arg(kSchemaVersion));
    return true;
}

bool LibraryService::migrateV1ToV2() {
    QFile backup(m_databasePath + QStringLiteral(".v1.bak"));
    if (!backup.exists()) {
        QFile::copy(m_databasePath, backup.fileName());
    }

    QList<User> migratedUsers;
    QList<Book> migratedBooks;
    QList<Loan> migratedLoans;

    QSqlQuery usersQuery(m_db);
    if (!usersQuery.exec(QStringLiteral(
            "SELECT id, username_enc, password_enc, admin_enc FROM users ORDER BY rowid"))) {
        setStorageError(QStringLiteral("迁移旧账户失败：%1").arg(usersQuery.lastError().text()));
        return false;
    }
    while (usersQuery.next()) {
        const QString uuid = usersQuery.value(0).toString();
        bool ok = false;
        const QString username = decryptText(usersQuery.value(1).toByteArray(),
                                             userAad(uuid, "username"), &ok);
        if (!ok) {
            return false;
        }
        const QString password = decryptText(usersQuery.value(2).toByteArray(),
                                             userAad(uuid, "password"), &ok);
        if (!ok) {
            return false;
        }
        const QString adminText = decryptText(usersQuery.value(3).toByteArray(),
                                              userAad(uuid, "admin"), &ok);
        if (!ok) {
            return false;
        }
        User user;
        user.username = username.trimmed();
        if (user.username.isEmpty()) {
            continue;
        }
        user.displayName = user.username;
        user.passwordSalt = makeSalt();
        user.passwordHash = hashPassword(password.isEmpty() ? QStringLiteral("ChangeMe123!")
                                                             : password,
                                         user.passwordSalt);
        user.admin = parseBool(adminText);
        user.mustChangePassword = user.username.compare(QStringLiteral("Administrator"),
                                                        Qt::CaseInsensitive) == 0;
        migratedUsers.append(user);
    }

    QSqlQuery booksQuery(m_db);
    if (!booksQuery.exec(QStringLiteral(
            "SELECT number, name_enc, author_enc, publisher_enc, place_enc, "
            "borrower_enc, borrowed_at_enc FROM books ORDER BY number"))) {
        setStorageError(QStringLiteral("迁移旧图书失败：%1").arg(booksQuery.lastError().text()));
        return false;
    }
    qint64 loanId = 1;
    while (booksQuery.next()) {
        Book book;
        book.number = booksQuery.value(0).toInt();
        bool ok = false;
        book.name = decryptText(booksQuery.value(1).toByteArray(),
                                bookAad(book.number, "name"), &ok);
        if (!ok) {
            return false;
        }
        book.author = decryptText(booksQuery.value(2).toByteArray(),
                                  bookAad(book.number, "author"), &ok);
        if (!ok) {
            return false;
        }
        book.publisher = decryptText(booksQuery.value(3).toByteArray(),
                                     bookAad(book.number, "publisher"), &ok);
        if (!ok) {
            return false;
        }
        book.place = decryptText(booksQuery.value(4).toByteArray(),
                                 bookAad(book.number, "place"), &ok);
        if (!ok) {
            return false;
        }
        const QString borrower = decryptText(booksQuery.value(5).toByteArray(),
                                             bookAad(book.number, "borrower"), &ok);
        if (!ok) {
            return false;
        }
        const QString borrowedAt = decryptText(booksQuery.value(6).toByteArray(),
                                               bookAad(book.number, "borrowedAt"), &ok);
        if (!ok) {
            return false;
        }
        book.category = QStringLiteral("未分类");
        migratedBooks.append(book);

        if (!borrower.isEmpty()) {
            Loan loan;
            loan.id = loanId++;
            loan.bookNumber = book.number;
            loan.username = borrower;
            loan.borrowedAt = QDateTime::fromString(borrowedAt, Qt::ISODate);
            if (!loan.borrowedAt.isValid()) {
                loan.borrowedAt = QDateTime::currentDateTime();
            }
            loan.dueAt = loan.borrowedAt.addMonths(1);
            migratedLoans.append(loan);
        }
    }

    QSqlQuery drop(m_db);
    drop.exec(QStringLiteral("DROP TABLE IF EXISTS loans"));
    drop.exec(QStringLiteral("DROP TABLE IF EXISTS books"));
    drop.exec(QStringLiteral("DROP TABLE IF EXISTS users"));

    m_users = migratedUsers;
    m_books = migratedBooks;
    m_loans = migratedLoans;
    m_lastBookNumber = 0;
    for (const Book &book : m_books) {
        m_lastBookNumber = std::max(m_lastBookNumber, book.number);
    }
    refreshBookLoanState();
    ensureDefaultAdmin();

    QSqlQuery versionQuery(m_db);
    versionQuery.exec(QStringLiteral("PRAGMA user_version = 0"));

    if (!createSchema()) {
        return false;
    }
    if (!persistAll()) {
        setStorageError(QStringLiteral("写入新数据库结构失败：%1").arg(m_lastError));
        return false;
    }
    return true;
}

bool LibraryService::loadFromDatabase() {
    m_users.clear();
    m_books.clear();
    m_loans.clear();
    m_lastBookNumber = 0;

    QSqlQuery usersQuery(m_db);
    if (!usersQuery.exec(QStringLiteral(
            "SELECT id, username_enc, display_name_enc, password_hash_enc, password_salt_enc, "
            "admin_enc, must_change_enc, locked_enc, failed_attempts_enc, lock_until_enc, "
            "avatar_enc FROM users ORDER BY rowid"))) {
        setStorageError(QStringLiteral("读取账户数据失败：%1").arg(usersQuery.lastError().text()));
        return false;
    }
    while (usersQuery.next()) {
        const QString uuid = usersQuery.value(0).toString();
        bool ok = false;
        User user;
        user.username = decryptText(usersQuery.value(1).toByteArray(),
                                    userAad(uuid, "username"), &ok).trimmed();
        if (!ok || user.username.isEmpty()) {
            return false;
        }
        user.displayName = decryptText(usersQuery.value(2).toByteArray(),
                                       userAad(uuid, "displayName"), &ok);
        if (!ok) {
            return false;
        }
        user.passwordHash = decryptBlob(usersQuery.value(3).toByteArray(),
                                        userAad(uuid, "passwordHash"), &ok);
        if (!ok) {
            return false;
        }
        user.passwordSalt = decryptBlob(usersQuery.value(4).toByteArray(),
                                        userAad(uuid, "passwordSalt"), &ok);
        if (!ok) {
            return false;
        }
        user.admin = parseBool(decryptText(usersQuery.value(5).toByteArray(),
                                           userAad(uuid, "admin"), &ok));
        if (!ok) {
            return false;
        }
        user.mustChangePassword = parseBool(decryptText(usersQuery.value(6).toByteArray(),
                                                        userAad(uuid, "mustChange"), &ok));
        if (!ok) {
            return false;
        }
        user.locked = parseBool(decryptText(usersQuery.value(7).toByteArray(),
                                            userAad(uuid, "locked"), &ok));
        if (!ok) {
            return false;
        }
        user.failedAttempts = decryptText(usersQuery.value(8).toByteArray(),
                                          userAad(uuid, "failedAttempts"), &ok).toInt();
        if (!ok) {
            return false;
        }
        user.lockUntil = QDateTime::fromString(
                decryptText(usersQuery.value(9).toByteArray(),
                            userAad(uuid, "lockUntil"), &ok), Qt::ISODate);
        if (!ok) {
            return false;
        }
        user.avatar = decryptBlob(usersQuery.value(10).toByteArray(),
                                  userAad(uuid, "avatar"), &ok);
        if (!ok) {
            return false;
        }
        if (user.displayName.isEmpty()) {
            user.displayName = user.username;
        }
        if (indexOfUser(user.username) < 0) {
            m_users.append(user);
        }
    }

    QSqlQuery booksQuery(m_db);
    if (!booksQuery.exec(QStringLiteral(
            "SELECT number, name_enc, author_enc, publisher_enc, place_enc, "
            "category_enc, description_enc, cover_enc FROM books ORDER BY number"))) {
        setStorageError(QStringLiteral("读取图书数据失败：%1").arg(booksQuery.lastError().text()));
        return false;
    }
    while (booksQuery.next()) {
        Book book;
        book.number = booksQuery.value(0).toInt();
        bool ok = false;
        book.name = decryptText(booksQuery.value(1).toByteArray(),
                                bookAad(book.number, "name"), &ok);
        if (!ok) {
            return false;
        }
        book.author = decryptText(booksQuery.value(2).toByteArray(),
                                  bookAad(book.number, "author"), &ok);
        if (!ok) {
            return false;
        }
        book.publisher = decryptText(booksQuery.value(3).toByteArray(),
                                     bookAad(book.number, "publisher"), &ok);
        if (!ok) {
            return false;
        }
        book.place = decryptText(booksQuery.value(4).toByteArray(),
                                 bookAad(book.number, "place"), &ok);
        if (!ok) {
            return false;
        }
        book.category = decryptText(booksQuery.value(5).toByteArray(),
                                    bookAad(book.number, "category"), &ok);
        if (!ok) {
            return false;
        }
        book.description = decryptText(booksQuery.value(6).toByteArray(),
                                       bookAad(book.number, "description"), &ok);
        if (!ok) {
            return false;
        }
        book.cover = decryptBlob(booksQuery.value(7).toByteArray(),
                                 bookAad(book.number, "cover"), &ok);
        if (!ok) {
            return false;
        }
        book.category = book.category.isEmpty() ? QStringLiteral("未分类") : book.category;
        if (book.number <= 0 || book.name.isEmpty() || indexOfBook(book.number) >= 0) {
            continue;
        }
        m_books.append(book);
        m_lastBookNumber = std::max(m_lastBookNumber, book.number);
    }

    QSqlQuery loansQuery(m_db);
    if (!loansQuery.exec(QStringLiteral(
            "SELECT id, book_number, username_enc, borrowed_at_enc, due_at_enc, "
            "returned_at_enc, renew_count_enc, manual_unreturned_enc "
            "FROM loans ORDER BY id"))) {
        setStorageError(QStringLiteral("读取借阅历史失败：%1").arg(loansQuery.lastError().text()));
        return false;
    }
    while (loansQuery.next()) {
        Loan loan;
        loan.id = loansQuery.value(0).toLongLong();
        loan.bookNumber = loansQuery.value(1).toInt();
        bool ok = false;
        loan.username = decryptText(loansQuery.value(2).toByteArray(),
                                    loanAad(loan.id, "username"), &ok);
        if (!ok) {
            return false;
        }
        loan.borrowedAt = QDateTime::fromString(
                decryptText(loansQuery.value(3).toByteArray(),
                            loanAad(loan.id, "borrowedAt"), &ok), Qt::ISODate);
        if (!ok) {
            return false;
        }
        loan.dueAt = QDateTime::fromString(
                decryptText(loansQuery.value(4).toByteArray(),
                            loanAad(loan.id, "dueAt"), &ok), Qt::ISODate);
        if (!ok) {
            return false;
        }
        loan.returnedAt = QDateTime::fromString(
                decryptText(loansQuery.value(5).toByteArray(),
                            loanAad(loan.id, "returnedAt"), &ok), Qt::ISODate);
        if (!ok) {
            return false;
        }
        loan.renewCount = decryptText(loansQuery.value(6).toByteArray(),
                                      loanAad(loan.id, "renewCount"), &ok).toInt();
        if (!ok) {
            return false;
        }
        loan.manualUnreturned = parseBool(decryptText(
                loansQuery.value(7).toByteArray(),
                loanAad(loan.id, "manualUnreturned"), &ok));
        if (!ok) {
            return false;
        }
        if (loan.id > 0 && loan.bookNumber > 0 && indexOfBook(loan.bookNumber) >= 0) {
            m_loans.append(loan);
        }
    }

    refreshBookLoanState();
    return true;
}

bool LibraryService::persistAll() {
    if (!m_db.isOpen()) {
        setLastError(QStringLiteral("数据库未打开，无法保存数据"));
        return false;
    }
    if (!m_db.transaction()) {
        setLastError(QStringLiteral("无法开始数据库事务：%1").arg(m_db.lastError().text()));
        return false;
    }

    auto rollback = [this]() {
        m_db.rollback();
    };

    QSqlQuery clear(m_db);
    if (!clear.exec(QStringLiteral("DELETE FROM loans"))
        || !clear.exec(QStringLiteral("DELETE FROM books"))
        || !clear.exec(QStringLiteral("DELETE FROM users"))) {
        setLastError(QStringLiteral("清理旧数据失败：%1").arg(clear.lastError().text()));
        rollback();
        return false;
    }

    for (const User &user : m_users) {
        const QString uuid = QUuid::createUuid().toString(QUuid::WithoutBraces);
        bool ok = false;
        const QByteArray username = encryptText(user.username, userAad(uuid, "username"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray displayName = encryptText(user.displayName.isEmpty() ? user.username
                                                                              : user.displayName,
                                                   userAad(uuid, "displayName"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray passwordHash = encryptBlob(user.passwordHash,
                                                    userAad(uuid, "passwordHash"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray passwordSalt = encryptBlob(user.passwordSalt,
                                                    userAad(uuid, "passwordSalt"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray admin = encryptText(user.admin ? QStringLiteral("1") : QStringLiteral("0"),
                                             userAad(uuid, "admin"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray mustChange = encryptText(user.mustChangePassword ? QStringLiteral("1")
                                                                          : QStringLiteral("0"),
                                                  userAad(uuid, "mustChange"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray locked = encryptText(user.locked ? QStringLiteral("1") : QStringLiteral("0"),
                                              userAad(uuid, "locked"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray failed = encryptText(QString::number(user.failedAttempts),
                                              userAad(uuid, "failedAttempts"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray lockUntil = encryptText(user.lockUntil.isValid()
                                                         ? user.lockUntil.toString(Qt::ISODate)
                                                         : QString(),
                                                 userAad(uuid, "lockUntil"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray avatar = encryptBlob(user.avatar, userAad(uuid, "avatar"), &ok);
        if (!ok) {
            rollback();
            return false;
        }

        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral(
                "INSERT INTO users(id, username_enc, display_name_enc, password_hash_enc, "
                "password_salt_enc, admin_enc, must_change_enc, locked_enc, "
                "failed_attempts_enc, lock_until_enc, avatar_enc) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"));
        insert.addBindValue(uuid);
        insert.addBindValue(username);
        insert.addBindValue(displayName);
        insert.addBindValue(passwordHash);
        insert.addBindValue(passwordSalt);
        insert.addBindValue(admin);
        insert.addBindValue(mustChange);
        insert.addBindValue(locked);
        insert.addBindValue(failed);
        insert.addBindValue(lockUntil);
        insert.addBindValue(avatar);
        if (!insert.exec()) {
            setLastError(QStringLiteral("保存账户失败：%1").arg(insert.lastError().text()));
            rollback();
            return false;
        }
    }

    for (const Book &book : m_books) {
        bool ok = false;
        const QByteArray name = encryptText(book.name, bookAad(book.number, "name"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray author = encryptText(book.author, bookAad(book.number, "author"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray publisher = encryptText(book.publisher,
                                                 bookAad(book.number, "publisher"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray place = encryptText(book.place, bookAad(book.number, "place"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray category = encryptText(book.category,
                                                bookAad(book.number, "category"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray description = encryptText(book.description,
                                                   bookAad(book.number, "description"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray cover = encryptBlob(book.cover, bookAad(book.number, "cover"), &ok);
        if (!ok) {
            rollback();
            return false;
        }

        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral(
                "INSERT INTO books(number, name_enc, author_enc, publisher_enc, place_enc, "
                "category_enc, description_enc, cover_enc) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"));
        insert.addBindValue(book.number);
        insert.addBindValue(name);
        insert.addBindValue(author);
        insert.addBindValue(publisher);
        insert.addBindValue(place);
        insert.addBindValue(category);
        insert.addBindValue(description);
        insert.addBindValue(cover);
        if (!insert.exec()) {
            setLastError(QStringLiteral("保存图书失败：%1").arg(insert.lastError().text()));
            rollback();
            return false;
        }
    }

    for (const Loan &loan : m_loans) {
        bool ok = false;
        const QByteArray username = encryptText(loan.username,
                                                loanAad(loan.id, "username"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray borrowedAt = encryptText(formatDate(loan.borrowedAt),
                                                  loanAad(loan.id, "borrowedAt"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray dueAt = encryptText(formatDate(loan.dueAt),
                                             loanAad(loan.id, "dueAt"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray returnedAt = encryptText(formatDate(loan.returnedAt),
                                                  loanAad(loan.id, "returnedAt"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray renewCount = encryptText(QString::number(loan.renewCount),
                                                  loanAad(loan.id, "renewCount"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray manual = encryptText(loan.manualUnreturned ? QStringLiteral("1")
                                                                    : QStringLiteral("0"),
                                              loanAad(loan.id, "manualUnreturned"), &ok);
        if (!ok) {
            rollback();
            return false;
        }

        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral(
                "INSERT INTO loans(id, book_number, username_enc, borrowed_at_enc, "
                "due_at_enc, returned_at_enc, renew_count_enc, manual_unreturned_enc) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"));
        insert.addBindValue(loan.id);
        insert.addBindValue(loan.bookNumber);
        insert.addBindValue(username);
        insert.addBindValue(borrowedAt);
        insert.addBindValue(dueAt);
        insert.addBindValue(returnedAt);
        insert.addBindValue(renewCount);
        insert.addBindValue(manual);
        if (!insert.exec()) {
            setLastError(QStringLiteral("保存借阅记录失败：%1").arg(insert.lastError().text()));
            rollback();
            return false;
        }
    }

    if (!m_db.commit()) {
        setLastError(QStringLiteral("提交数据库事务失败：%1").arg(m_db.lastError().text()));
        rollback();
        return false;
    }
    return true;
}

void LibraryService::closeDatabase() {
    if (m_db.isValid()) {
        m_db.close();
    }
    m_db = QSqlDatabase();
    if (QSqlDatabase::contains(m_connectionName)) {
        QSqlDatabase::removeDatabase(m_connectionName);
    }
}

QByteArray LibraryService::encryptText(const QString &text, const QByteArray &aad, bool *ok) {
    QString error;
    const QByteArray blob = Encryption::instance().encrypt(text.toUtf8(), aad, &error);
    if (blob.isEmpty()) {
        if (ok) {
            *ok = false;
        }
        setLastError(QStringLiteral("加密数据失败：%1").arg(error));
        return {};
    }
    if (ok) {
        *ok = true;
    }
    return blob;
}

QByteArray LibraryService::encryptBlob(const QByteArray &data, const QByteArray &aad, bool *ok) {
    QString error;
    const QByteArray blob = Encryption::instance().encrypt(data, aad, &error);
    if (blob.isEmpty()) {
        if (ok) {
            *ok = false;
        }
        setLastError(QStringLiteral("加密数据失败：%1").arg(error));
        return {};
    }
    if (ok) {
        *ok = true;
    }
    return blob;
}

QString LibraryService::decryptText(const QByteArray &blob, const QByteArray &aad, bool *ok) {
    QString error;
    const QByteArray plaintext = Encryption::instance().decrypt(blob, aad, &error);
    if (!error.isEmpty()) {
        if (ok) {
            *ok = false;
        }
        setStorageError(QStringLiteral("解密数据库字段失败：%1").arg(error));
        return {};
    }
    if (ok) {
        *ok = true;
    }
    return QString::fromUtf8(plaintext);
}

QByteArray LibraryService::decryptBlob(const QByteArray &blob, const QByteArray &aad, bool *ok) {
    QString error;
    const QByteArray plaintext = Encryption::instance().decrypt(blob, aad, &error);
    if (!error.isEmpty()) {
        if (ok) {
            *ok = false;
        }
        setStorageError(QStringLiteral("解密数据库字段失败：%1").arg(error));
        return {};
    }
    if (ok) {
        *ok = true;
    }
    return plaintext;
}

QByteArray LibraryService::bookAad(int number, const char *field) const {
    return QStringLiteral("library/book/%1/%2")
            .arg(number)
            .arg(QString::fromLatin1(field))
            .toUtf8();
}

QByteArray LibraryService::userAad(const QString &uuid, const char *field) const {
    return QStringLiteral("library/user/%1/%2")
            .arg(uuid, QString::fromLatin1(field))
            .toUtf8();
}

QByteArray LibraryService::loanAad(qint64 id, const char *field) const {
    return QStringLiteral("library/loan/%1/%2")
            .arg(id)
            .arg(QString::fromLatin1(field))
            .toUtf8();
}

QByteArray LibraryService::makeSalt() {
    QByteArray salt(kPasswordSaltLength, '\0');
    for (int i = 0; i < kPasswordSaltLength; i += 4) {
        const quint32 value = QRandomGenerator::system()->generate();
        std::memcpy(salt.data() + i, &value, 4);
    }
    return salt;
}

QByteArray LibraryService::hashPassword(const QString &password, const QByteArray &salt) {
    return pbkdf2(password.toUtf8(), salt, kPasswordIterations, kPasswordHashLength).toHex();
}

bool LibraryService::verifyPassword(const QString &password, const QByteArray &hash,
                                    const QByteArray &salt) {
    if (hash.isEmpty() || salt.isEmpty()) {
        return false;
    }
    const QByteArray computed = hashPassword(password, salt);
    if (computed.size() != hash.size()) {
        return false;
    }
    int diff = 0;
    for (int i = 0; i < computed.size(); ++i) {
        diff |= computed.at(i) ^ hash.at(i);
    }
    return diff == 0;
}

QString LibraryService::validatePasswordStrength(const QString &password) {
    if (password.size() < 8) {
        return QStringLiteral("密码至少需要 8 个字符");
    }
    bool upper = false;
    bool lower = false;
    bool digit = false;
    bool special = false;
    for (const QChar ch : password) {
        if (ch >= QLatin1Char('A') && ch <= QLatin1Char('Z')) {
            upper = true;
        } else if (ch >= QLatin1Char('a') && ch <= QLatin1Char('z')) {
            lower = true;
        } else if (ch.isDigit()) {
            digit = true;
        } else if (!ch.isSpace() && !ch.isLetterOrNumber()) {
            special = true;
        }
    }
    if (!upper || !lower) {
        return QStringLiteral("密码必须同时包含大写和小写字母");
    }
    if (!digit) {
        return QStringLiteral("密码必须包含数字");
    }
    if (!special) {
        return QStringLiteral("密码必须包含特殊符号（如 !@#$%）");
    }
    return {};
}

void LibraryService::refreshBookLoanState() {
    for (Book &book : m_books) {
        book.borrower.clear();
        book.borrowedAt = QDateTime();
        book.dueAt = QDateTime();
        book.renewCount = 0;
        book.activeLoanId = 0;
    }
    for (const Loan &loan : m_loans) {
        if (loan.returnedAt.isValid()) {
            continue;
        }
        const int index = indexOfBook(loan.bookNumber);
        if (index < 0) {
            continue;
        }
        Book &book = m_books[index];
        if (book.activeLoanId != 0) {
            continue;
        }
        book.borrower = loan.username;
        book.borrowedAt = loan.borrowedAt;
        book.dueAt = loan.dueAt;
        book.renewCount = loan.renewCount;
        book.activeLoanId = loan.id;
    }
}

void LibraryService::bumpImageRevision() {
    ++m_imageRevision;
    emit imageRevisionChanged();
}

bool LibraryService::isUserBlacklisted(const QString &username) const {
    if (username.isEmpty()) {
        return false;
    }
    const QDateTime now = QDateTime::currentDateTime();
    for (const Loan &loan : m_loans) {
        if (loan.returnedAt.isValid()
            || loan.username.compare(username, Qt::CaseInsensitive) != 0) {
            continue;
        }
        if (loan.manualUnreturned || (loan.dueAt.isValid() && loan.dueAt < now)) {
            return true;
        }
    }
    return false;
}

int LibraryService::activeLoanCountForUser(const QString &username) const {
    if (username.isEmpty()) {
        return 0;
    }
    int count = 0;
    for (const Loan &loan : m_loans) {
        if (!loan.returnedAt.isValid()
            && loan.username.compare(username, Qt::CaseInsensitive) == 0) {
            ++count;
        }
    }
    return count;
}

int LibraryService::activeLoanIndexForBook(int number) const {
    for (int i = 0; i < m_loans.size(); ++i) {
        if (m_loans.at(i).bookNumber == number && !m_loans.at(i).returnedAt.isValid()) {
            return i;
        }
    }
    return -1;
}

int LibraryService::loanIndexById(qint64 id) const {
    for (int i = 0; i < m_loans.size(); ++i) {
        if (m_loans.at(i).id == id) {
            return i;
        }
    }
    return -1;
}

QDateTime LibraryService::nextDueDate(const QDateTime &from) const {
    return from.addMonths(1);
}

QString LibraryService::displayNameFor(const QString &username) const {
    const int index = indexOfUser(username);
    if (index < 0) {
        return username;
    }
    const QString displayName = m_users.at(index).displayName;
    return displayName.isEmpty() ? m_users.at(index).username : displayName;
}

QString LibraryService::currentDisplayName() const {
    return displayNameFor(m_currentUser);
}

bool LibraryService::currentHasAvatar() const {
    if (m_currentUser.isEmpty()) {
        return false;
    }
    const int index = indexOfUser(m_currentUser);
    return index >= 0 && !m_users.at(index).avatar.isEmpty();
}

bool LibraryService::isAdmin() const {
    if (m_currentUser.isEmpty()) {
        return false;
    }
    const int index = indexOfUser(m_currentUser);
    return index >= 0 && m_users.at(index).admin;
}

bool LibraryService::mustChangePassword() const {
    const int index = indexOfUser(m_currentUser);
    return index >= 0 && m_users.at(index).mustChangePassword;
}

bool LibraryService::blacklisted() const {
    return isUserBlacklisted(m_currentUser);
}

QVariantList LibraryService::books() const {
    QVariantList out;
    out.reserve(m_books.size());
    for (const Book &book : m_books) {
        out.append(toMap(book));
    }
    return out;
}

QVariantList LibraryService::availableBooks() const {
    QVariantList out;
    for (const Book &book : m_books) {
        if (book.activeLoanId == 0) {
            out.append(toMap(book));
        }
    }
    return out;
}

QVariantList LibraryService::borrowedBooks() const {
    QVariantList out;
    for (const Book &book : m_books) {
        if (book.activeLoanId != 0) {
            out.append(toMap(book));
        }
    }
    return out;
}

QVariantList LibraryService::myBorrowedBooks() const {
    QVariantList out;
    if (m_currentUser.isEmpty()) {
        return out;
    }
    for (const Book &book : m_books) {
        if (book.activeLoanId != 0
            && book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
            out.append(toMap(book));
        }
    }
    return out;
}

QVariantList LibraryService::users() const {
    QVariantList out;
    out.reserve(m_users.size());
    for (const User &user : m_users) {
        out.append(userMap(user));
    }
    return out;
}

int LibraryService::myBorrowCount() const {
    return activeLoanCountForUser(m_currentUser);
}

QVariantMap LibraryService::stats() const {
    int available = 0;
    int overdue = 0;
    const QDateTime now = QDateTime::currentDateTime();
    for (const Book &book : m_books) {
        if (book.activeLoanId == 0) {
            ++available;
        } else if (book.dueAt.isValid() && book.dueAt < now) {
            ++overdue;
        }
    }
    int blacklistedUsers = 0;
    int lockedUsers = 0;
    for (const User &user : m_users) {
        if (isUserBlacklisted(user.username)) {
            ++blacklistedUsers;
        }
        if (user.locked
            || (user.lockUntil.isValid() && user.lockUntil > QDateTime::currentDateTime())) {
            ++lockedUsers;
        }
    }
    const int mine = myBorrowCount();

    QVariantMap map;
    map.insert(QStringLiteral("totalBooks"), m_books.size());
    map.insert(QStringLiteral("availableBooks"), available);
    map.insert(QStringLiteral("borrowedBooks"), m_books.size() - available);
    map.insert(QStringLiteral("overdueBooks"), overdue);
    map.insert(QStringLiteral("totalUsers"), m_users.size());
    map.insert(QStringLiteral("lockedUsers"), lockedUsers);
    map.insert(QStringLiteral("blacklistedUsers"), blacklistedUsers);
    map.insert(QStringLiteral("totalLoans"), m_loans.size());
    map.insert(QStringLiteral("myBorrowCount"), mine);
    map.insert(QStringLiteral("myRemaining"), std::max(0, m_limit - mine));
    map.insert(QStringLiteral("borrowLimit"), m_limit);
    map.insert(QStringLiteral("blacklisted"), blacklisted());
    return map;
}

bool LibraryService::login(const QString &username, const QString &password) {
    if (!m_storageReady) {
        fail(QStringLiteral("数据库不可用，无法登录：%1").arg(m_storageError));
        return false;
    }
    const QString name = username.trimmed();
    if (name.isEmpty() || password.isEmpty()) {
        fail(QStringLiteral("请输入用户名和密码"));
        return false;
    }
    const int index = indexOfUser(name);
    if (index < 0) {
        fail(QStringLiteral("用户名或密码错误"));
        return false;
    }

    User &user = m_users[index];
    const QDateTime now = QDateTime::currentDateTime();
    if (user.locked) {
        fail(QStringLiteral("账号已被管理员锁定，请联系管理员解锁"));
        return false;
    }
    if (user.lockUntil.isValid() && user.lockUntil > now) {
        const qint64 seconds = now.secsTo(user.lockUntil);
        const int minutes = static_cast<int>((seconds + 59) / 60);
        fail(QStringLiteral("密码连续错误次数过多，账号已临时锁定，请在 %1 分钟后重试")
                     .arg(minutes));
        return false;
    }
    if (user.lockUntil.isValid() && user.lockUntil <= now) {
        user.lockUntil = QDateTime();
        user.failedAttempts = 0;
    }

    if (!verifyPassword(password, user.passwordHash, user.passwordSalt)) {
        ++user.failedAttempts;
        QString message;
        if (user.failedAttempts >= kMaxLoginFailures) {
            user.failedAttempts = 0;
            user.lockUntil = now.addSecs(kLoginLockMinutes * 60);
            message = QStringLiteral("密码连续错误 %1 次，账号已锁定 %2 分钟")
                              .arg(kMaxLoginFailures)
                              .arg(kLoginLockMinutes);
        } else {
            message = QStringLiteral("用户名或密码错误，还可尝试 %1 次")
                              .arg(kMaxLoginFailures - user.failedAttempts);
        }
        persistAll();
        fail(message);
        return false;
    }

    const bool resetLock = user.failedAttempts != 0 || user.lockUntil.isValid();
    user.failedAttempts = 0;
    user.lockUntil = QDateTime();
    m_currentUser = user.username;
    if (resetLock) {
        persistAll();
    }
    setLastError(QString());
    emit sessionChanged();
    emit booksChanged();
    emit usersChanged();
    return true;
}

void LibraryService::logout() {
    if (m_currentUser.isEmpty()) {
        return;
    }
    m_currentUser.clear();
    setLastError(QString());
    emit sessionChanged();
    emit booksChanged();
}

QString LibraryService::borrowBook(int number) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法借阅：%1").arg(m_storageError));
    }
    if (!isLoggedIn()) {
        return fail(QStringLiteral("请先登录后再借阅图书"));
    }
    if (isAdmin()) {
        return fail(QStringLiteral("管理员账号不能借阅图书，请使用读者账号"));
    }
    const int index = indexOfBook(number);
    if (index < 0) {
        return fail(QStringLiteral("未找到索书号为 %1 的图书").arg(number));
    }
    Book &book = m_books[index];
    if (book.activeLoanId != 0) {
        if (book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
            return fail(QStringLiteral("你已借阅《%1》，请勿重复借阅").arg(book.name));
        }
        return fail(QStringLiteral("《%1》已被借出，请选择其他图书").arg(book.name));
    }
    if (activeLoanCountForUser(m_currentUser) >= m_limit) {
        return fail(QStringLiteral("已达到借阅上限（%1 本），请先归还部分图书").arg(m_limit));
    }
    if (isUserBlacklisted(m_currentUser)) {
        return fail(QStringLiteral("你有逾期未还图书，已被列入黑名单，请先归还后再借阅"));
    }

    Loan loan;
    loan.id = nextLoanId();
    loan.bookNumber = number;
    loan.username = m_currentUser;
    loan.borrowedAt = QDateTime::currentDateTime();
    loan.dueAt = nextDueDate(loan.borrowedAt);
    m_loans.append(loan);
    refreshBookLoanState();
    if (!persistAll()) {
        m_loans.removeLast();
        refreshBookLoanState();
        return lastError();
    }

    setLastError(QString());
    emit booksChanged();
    emit usersChanged();
    return {};
}

QString LibraryService::returnBook(int number) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法归还：%1").arg(m_storageError));
    }
    if (!isLoggedIn()) {
        return fail(QStringLiteral("请先登录后再归还图书"));
    }
    if (isAdmin()) {
        return fail(QStringLiteral("管理员不能自行归还图书，请在管理中心帮助用户归还"));
    }
    const int loanIndex = activeLoanIndexForBook(number);
    if (loanIndex < 0) {
        return fail(QStringLiteral("该图书当前没有未还记录"));
    }
    Loan &loan = m_loans[loanIndex];
    if (loan.username.compare(m_currentUser, Qt::CaseInsensitive) != 0) {
        return fail(QStringLiteral("该图书并非由你借阅，无法归还"));
    }
    loan.returnedAt = QDateTime::currentDateTime();
    loan.manualUnreturned = false;
    refreshBookLoanState();
    if (!persistAll()) {
        loan.returnedAt = QDateTime();
        refreshBookLoanState();
        return lastError();
    }

    setLastError(QString());
    emit booksChanged();
    emit usersChanged();
    return {};
}

QString LibraryService::renewBook(int number) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法续借：%1").arg(m_storageError));
    }
    if (!isLoggedIn()) {
        return fail(QStringLiteral("请先登录后再续借"));
    }
    if (isAdmin()) {
        return fail(QStringLiteral("管理员账号不能借阅或续借图书"));
    }
    const int loanIndex = activeLoanIndexForBook(number);
    if (loanIndex < 0) {
        return fail(QStringLiteral("该图书当前没有未还记录"));
    }
    Loan &loan = m_loans[loanIndex];
    if (loan.username.compare(m_currentUser, Qt::CaseInsensitive) != 0) {
        return fail(QStringLiteral("该图书并非由你借阅，无法续借"));
    }
    if (loan.renewCount >= 1) {
        return fail(QStringLiteral("每本图书只能续借一次"));
    }
    if (loan.dueAt.isValid() && loan.dueAt < QDateTime::currentDateTime()) {
        return fail(QStringLiteral("该图书已逾期，无法续借，请先归还"));
    }
    loan.dueAt = loan.dueAt.addMonths(1);
    loan.renewCount = 1;
    refreshBookLoanState();
    if (!persistAll()) {
        loan.dueAt = loan.dueAt.addMonths(-1);
        loan.renewCount = 0;
        refreshBookLoanState();
        return lastError();
    }

    setLastError(QString());
    emit booksChanged();
    return {};
}

QString LibraryService::adminReturnLoan(qint64 loanId) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法操作：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以执行此操作"));
    }
    const int index = loanIndexById(loanId);
    if (index < 0) {
        return fail(QStringLiteral("未找到对应的借阅记录"));
    }
    Loan &loan = m_loans[index];
    if (loan.returnedAt.isValid()) {
        return fail(QStringLiteral("该借阅记录已经归还"));
    }
    const QDateTime previous = loan.returnedAt;
    loan.returnedAt = QDateTime::currentDateTime();
    loan.manualUnreturned = false;
    refreshBookLoanState();
    if (!persistAll()) {
        loan.returnedAt = previous;
        refreshBookLoanState();
        return lastError();
    }
    setLastError(QString());
    emit booksChanged();
    emit usersChanged();
    return {};
}

QString LibraryService::adminMarkUnreturned(qint64 loanId) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法操作：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以执行此操作"));
    }
    const int index = loanIndexById(loanId);
    if (index < 0) {
        return fail(QStringLiteral("未找到对应的借阅记录"));
    }
    Loan &loan = m_loans[index];
    const bool wasReturned = loan.returnedAt.isValid();
    if (!wasReturned && loan.manualUnreturned) {
        return fail(QStringLiteral("该借阅记录已经标记为未还"));
    }
    if (wasReturned) {
        if (activeLoanIndexForBook(loan.bookNumber) >= 0) {
            return fail(QStringLiteral("该图书已有其他未还记录，无法重新标记"));
        }
        loan.returnedAt = QDateTime();
        if (!loan.dueAt.isValid()) {
            loan.dueAt = loan.borrowedAt.isValid() ? loan.borrowedAt.addMonths(1)
                                                   : QDateTime::currentDateTime();
        }
    }
    loan.manualUnreturned = true;
    refreshBookLoanState();
    if (!persistAll()) {
        loan.manualUnreturned = false;
        if (wasReturned) {
            loan.returnedAt = QDateTime::currentDateTime();
        }
        refreshBookLoanState();
        return lastError();
    }
    setLastError(QString());
    emit booksChanged();
    emit usersChanged();
    return {};
}

QVariantList LibraryService::bookLoans(int number) const {
    QVariantList out;
    if (!isAdmin()) {
        return out;
    }
    for (const Loan &loan : m_loans) {
        if (loan.bookNumber == number) {
            out.append(loanMap(loan));
        }
    }
    std::sort(out.begin(), out.end(), [](const QVariant &left, const QVariant &right) {
        return left.toMap().value(QStringLiteral("borrowedAtIso")).toString()
               > right.toMap().value(QStringLiteral("borrowedAtIso")).toString();
    });
    return out;
}

QString LibraryService::addBook(const QString &name,
                                const QString &author,
                                const QString &publisher,
                                const QString &place,
                                const QString &description,
                                const QString &category,
                                const QString &coverPath) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法添加图书：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以添加图书"));
    }
    const QString bookName = name.trimmed();
    if (bookName.isEmpty()) {
        return fail(QStringLiteral("请填写图书名称"));
    }
    if (bookName.size() > 100) {
        return fail(QStringLiteral("图书名称不能超过 100 个字符"));
    }

    QByteArray cover;
    if (!coverPath.trimmed().isEmpty()) {
        QFile file(coverPath);
        if (!file.open(QIODevice::ReadOnly)) {
            return fail(QStringLiteral("无法读取封面图片：%1").arg(file.errorString()));
        }
        if (file.size() > kMaxImageBytes) {
            return fail(QStringLiteral("封面图片不能超过 5 MB"));
        }
        cover = file.readAll();
        if (QImage::fromData(cover).isNull()) {
            return fail(QStringLiteral("封面图片格式无效"));
        }
    }

    Book book;
    book.number = nextBookNumber();
    book.name = bookName;
    book.author = author.trimmed().isEmpty() ? QStringLiteral("佚名") : author.trimmed();
    book.publisher = publisher.trimmed().isEmpty() ? QStringLiteral("未知") : publisher.trimmed();
    book.place = place.trimmed().isEmpty() ? QStringLiteral("未分类") : place.trimmed();
    book.category = category.trimmed().isEmpty() ? QStringLiteral("未分类") : category.trimmed();
    book.description = description.trimmed();
    book.cover = cover;

    const int previousLastNumber = m_lastBookNumber;
    m_books.append(book);
    m_lastBookNumber = book.number;
    if (!persistAll()) {
        m_books.removeLast();
        m_lastBookNumber = previousLastNumber;
        return lastError();
    }

    bumpImageRevision();
    setLastError(QString());
    emit booksChanged();
    return {};
}

QString LibraryService::addUser(const QString &username, const QString &password) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法添加账户：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以添加账户"));
    }
    const QString name = username.trimmed();
    if (!isValidUsername(name)) {
        return fail(QStringLiteral("账号需为 1-20 个字符，且不能包含空格或斜杠"));
    }
    if (name == QStringLiteral("0")) {
        return fail(QStringLiteral("账号 0 是旧版程序的退出指令，请换一个账号名"));
    }
    if (indexOfUser(name) >= 0) {
        return fail(QStringLiteral("账号“%1”已存在").arg(name));
    }
    const QString policyError = validatePasswordStrength(password);
    if (!policyError.isEmpty()) {
        return fail(policyError);
    }

    User user;
    user.username = name;
    user.displayName = name;
    user.passwordSalt = makeSalt();
    user.passwordHash = hashPassword(password, user.passwordSalt);
    user.admin = false;
    user.mustChangePassword = true;
    m_users.append(user);
    if (!persistAll()) {
        m_users.removeLast();
        return lastError();
    }

    setLastError(QString());
    emit usersChanged();
    emit booksChanged();
    return {};
}

QString LibraryService::resetPassword(const QString &username, const QString &newPassword) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法重置密码：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以重置密码"));
    }
    const int index = indexOfUser(username);
    if (index < 0) {
        return fail(QStringLiteral("账号“%1”不存在").arg(username));
    }
    const QString policyError = validatePasswordStrength(newPassword);
    if (!policyError.isEmpty()) {
        return fail(policyError);
    }

    User &user = m_users[index];
    user.passwordSalt = makeSalt();
    user.passwordHash = hashPassword(newPassword, user.passwordSalt);
    user.mustChangePassword = true;
    user.failedAttempts = 0;
    user.lockUntil = QDateTime();
    if (user.username.compare(QStringLiteral("Administrator"), Qt::CaseInsensitive) == 0) {
        m_prefillDefaultAdmin = false;
    }
    if (!persistAll()) {
        return lastError();
    }
    setLastError(QString());
    emit usersChanged();
    emit booksChanged();
    return {};
}

QString LibraryService::changeOwnPassword(const QString &newPassword) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法修改密码：%1").arg(m_storageError));
    }
    if (!isLoggedIn()) {
        return fail(QStringLiteral("请先登录"));
    }
    const QString policyError = validatePasswordStrength(newPassword);
    if (!policyError.isEmpty()) {
        return fail(policyError);
    }
    const int index = indexOfUser(m_currentUser);
    if (index < 0) {
        return fail(QStringLiteral("当前账户不存在"));
    }

    User &user = m_users[index];
    user.passwordSalt = makeSalt();
    user.passwordHash = hashPassword(newPassword, user.passwordSalt);
    user.mustChangePassword = false;
    user.failedAttempts = 0;
    user.lockUntil = QDateTime();
    if (user.username.compare(QStringLiteral("Administrator"), Qt::CaseInsensitive) == 0) {
        m_prefillDefaultAdmin = false;
    }
    if (!persistAll()) {
        return lastError();
    }
    setLastError(QString());
    emit sessionChanged();
    emit usersChanged();
    return {};
}

QString LibraryService::updateProfile(const QString &displayName,
                                      const QString &username,
                                      const QString &avatarPath,
                                      bool clearAvatar) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法修改资料：%1").arg(m_storageError));
    }
    if (!isLoggedIn()) {
        return fail(QStringLiteral("请先登录"));
    }
    const int index = indexOfUser(m_currentUser);
    if (index < 0) {
        return fail(QStringLiteral("当前账户不存在"));
    }
    const QString name = displayName.trimmed();
    if (name.isEmpty()) {
        return fail(QStringLiteral("显示名称不能为空"));
    }
    if (name.size() > 30) {
        return fail(QStringLiteral("显示名称不能超过 30 个字符"));
    }
    const QString newUsername = username.trimmed();
    if (!isValidUsername(newUsername)) {
        return fail(QStringLiteral("账号名称须为 1-20 个字符，且不能包含空格或斜杠"));
    }
    if (newUsername == QStringLiteral("0")) {
        return fail(QStringLiteral("账号 0 是旧版命令保留名，请换一个账号名"));
    }
    const int duplicate = indexOfUser(newUsername);
    if (duplicate >= 0 && duplicate != index) {
        return fail(QStringLiteral("账号“%1”已存在").arg(newUsername));
    }

    QByteArray avatar = m_users.at(index).avatar;
    if (clearAvatar) {
        avatar.clear();
    } else if (!avatarPath.trimmed().isEmpty()) {
        QFile file(avatarPath);
        if (!file.open(QIODevice::ReadOnly)) {
            return fail(QStringLiteral("无法读取头像图片：%1").arg(file.errorString()));
        }
        if (file.size() > kMaxImageBytes) {
            return fail(QStringLiteral("头像图片不能超过 5 MB"));
        }
        avatar = file.readAll();
        if (QImage::fromData(avatar).isNull()) {
            return fail(QStringLiteral("头像图片格式无效"));
        }
    }

    const QString previousUsername = m_users.at(index).username;
    const QString previousDisplayName = m_users.at(index).displayName;
    const QByteArray previousAvatar = m_users.at(index).avatar;
    const QList<Loan> previousLoans = m_loans;
    m_users[index].username = newUsername;
    m_users[index].displayName = name;
    m_users[index].avatar = avatar;
    if (previousUsername != newUsername) {
        for (Loan &loan : m_loans) {
            if (loan.username.compare(previousUsername, Qt::CaseInsensitive) == 0) {
                loan.username = newUsername;
            }
        }
        m_currentUser = newUsername;
    }
    if (!persistAll()) {
        m_users[index].username = previousUsername;
        m_users[index].displayName = previousDisplayName;
        m_users[index].avatar = previousAvatar;
        m_loans = previousLoans;
        m_currentUser = previousUsername;
        return lastError();
    }

    bumpImageRevision();
    setLastError(QString());
    emit sessionChanged();
    emit usersChanged();
    emit booksChanged();
    return {};
}

QString LibraryService::setUserLocked(const QString &username, bool locked) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法操作：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以锁定或解锁账户"));
    }
    const int index = indexOfUser(username);
    if (index < 0) {
        return fail(QStringLiteral("账号“%1”不存在").arg(username));
    }
    if (m_users.at(index).username.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
        return fail(QStringLiteral("不能锁定当前登录的账号"));
    }
    if (m_users.at(index).username.compare(QStringLiteral("Administrator"),
                                           Qt::CaseInsensitive) == 0) {
        return fail(QStringLiteral("内置管理员账号不能被锁定"));
    }

    User &user = m_users[index];
    user.locked = locked;
    if (!locked) {
        user.failedAttempts = 0;
        user.lockUntil = QDateTime();
    }
    if (!persistAll()) {
        user.locked = !locked;
        return lastError();
    }
    setLastError(QString());
    emit usersChanged();
    emit booksChanged();
    return {};
}

QString LibraryService::removeUser(const QString &username) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法删除账户：%1").arg(m_storageError));
    }
    if (!isAdmin()) {
        return fail(QStringLiteral("只有管理员可以删除账户"));
    }
    const int index = indexOfUser(username);
    if (index < 0) {
        return fail(QStringLiteral("账号“%1”不存在").arg(username));
    }

    const User user = m_users.at(index);
    if (user.username.compare(QStringLiteral("Administrator"), Qt::CaseInsensitive) == 0) {
        return fail(QStringLiteral("内置管理员账号不可删除"));
    }
    if (user.username.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
        return fail(QStringLiteral("不能删除当前登录的账号"));
    }
    for (const Loan &loan : m_loans) {
        if (!loan.returnedAt.isValid()
            && loan.username.compare(user.username, Qt::CaseInsensitive) == 0) {
            return fail(QStringLiteral("账号“%1”还有未归还的图书，无法删除").arg(user.username));
        }
    }

    m_users.removeAt(index);
    if (!persistAll()) {
        m_users.insert(index, user);
        return lastError();
    }

    setLastError(QString());
    emit usersChanged();
    emit booksChanged();
    return {};
}

int LibraryService::seedSampleBooks() {
    if (!m_storageReady) {
        setLastError(QStringLiteral("数据库不可用，无法载入示例数据：%1").arg(m_storageError));
        return 0;
    }
    if (!isAdmin()) {
        setLastError(QStringLiteral("只有管理员可以载入示例数据"));
        return 0;
    }

    struct SeedBook {
        const char *name;
        const char *author;
        const char *publisher;
        const char *place;
        const char *category;
        const char *description;
    };

    static const SeedBook seeds[] = {
        {"红楼梦", "曹雪芹", "人民文学出版社", "A 区 · 01 架", "古典文学",
         "中国古典四大名著之一，以贾府兴衰为背景描绘封建社会百态。"},
        {"西游记", "吴承恩", "人民文学出版社", "A 区 · 02 架", "古典文学",
         "唐僧师徒西天取经的神魔小说，中国古典四大名著之一。"},
        {"水浒传", "施耐庵", "人民文学出版社", "A 区 · 03 架", "古典文学",
         "以北宋末年为背景的英雄传奇，中国古典四大名著之一。"},
        {"三国演义", "罗贯中", "人民文学出版社", "A 区 · 04 架", "古典文学",
         "描写东汉末年至三国时期政治与军事斗争的长篇历史小说。"},
        {"活着", "余华", "作家出版社", "B 区 · 01 架", "现代文学",
         "讲述普通人福贵在时代变迁中坚韧活着的故事。"},
        {"平凡的世界", "路遥", "北京十月文艺出版社", "B 区 · 02 架", "现代文学",
         "以中国城乡社会生活为背景，展现普通人的奋斗与爱情。"},
        {"百年孤独", "加西亚·马尔克斯", "南海出版公司", "C 区 · 01 架", "外国文学",
         "魔幻现实主义代表作，讲述布恩迪亚家族七代人的传奇。"},
        {"小王子", "安托万·德·圣埃克苏佩里", "人民文学出版社", "C 区 · 02 架", "外国文学",
         "写给大人的童话，关于爱、责任与纯真。"},
        {"人类简史", "尤瓦尔·赫拉利", "中信出版社", "D 区 · 01 架", "历史",
         "从认知革命到科学革命，重新理解人类文明的演进。"},
        {"代码大全", "史蒂夫·迈克康奈尔", "电子工业出版社", "E 区 · 01 架", "计算机",
         "软件构建领域的经典著作，覆盖设计与编码实践。"},
        {"Qt 6 C++ 开发指南", "王维波", "人民邮电出版社", "E 区 · 02 架", "计算机",
         "系统讲解 Qt 6 C++ 桌面开发与 QML 集成。"},
        {"深入理解计算机系统", "Randal E. Bryant", "机械工业出版社", "E 区 · 03 架", "计算机",
         "从程序员视角理解计算机系统的经典教材。"},
    };

    const int oldSize = m_books.size();
    const int previousLastNumber = m_lastBookNumber;
    int added = 0;
    for (const SeedBook &seed : seeds) {
        const QString name = QString::fromUtf8(seed.name);
        bool exists = false;
        for (const Book &book : m_books) {
            if (book.name == name) {
                exists = true;
                break;
            }
        }
        if (exists) {
            continue;
        }
        Book book;
        book.number = nextBookNumber();
        book.name = name;
        book.author = QString::fromUtf8(seed.author);
        book.publisher = QString::fromUtf8(seed.publisher);
        book.place = QString::fromUtf8(seed.place);
        book.category = QString::fromUtf8(seed.category);
        book.description = QString::fromUtf8(seed.description);
        m_books.append(book);
        m_lastBookNumber = book.number;
        ++added;
    }

    if (added == 0) {
        setLastError(QString());
        return 0;
    }
    if (!persistAll()) {
        while (m_books.size() > oldSize) {
            m_books.removeLast();
        }
        m_lastBookNumber = previousLastNumber;
        return 0;
    }

    bumpImageRevision();
    setLastError(QString());
    emit booksChanged();
    return added;
}

QVariantList LibraryService::searchBooks(const QString &keyword, int mode) const {
    const QString key = keyword.trimmed();
    QVariantList out;

    for (const Book &book : m_books) {
        bool match = key.isEmpty();
        if (!match) {
            switch (mode) {
            case 1:
                match = book.name.contains(key, Qt::CaseInsensitive);
                break;
            case 2:
                match = book.author.contains(key, Qt::CaseInsensitive);
                break;
            case 3:
                match = QString::number(book.number).contains(key);
                break;
            case 4:
                match = book.category.contains(key, Qt::CaseInsensitive);
                break;
            default:
                match = book.name.contains(key, Qt::CaseInsensitive)
                        || book.author.contains(key, Qt::CaseInsensitive)
                        || book.publisher.contains(key, Qt::CaseInsensitive)
                        || book.category.contains(key, Qt::CaseInsensitive)
                        || QString::number(book.number).contains(key);
                break;
            }
        }
        if (match) {
            out.append(toMap(book));
        }
    }

    std::sort(out.begin(), out.end(), [](const QVariant &left, const QVariant &right) {
        return left.toMap().value(QStringLiteral("number")).toInt()
               < right.toMap().value(QStringLiteral("number")).toInt();
    });
    return out;
}

QVariantMap LibraryService::findBook(int number) const {
    const int index = indexOfBook(number);
    if (index < 0) {
        return {};
    }
    return toMap(m_books.at(index));
}

bool LibraryService::openExternalUrl(const QString &url) {
    const QUrl target(url);
    if (!target.isValid() || target.scheme().isEmpty()) {
        return false;
    }
    return QDesktopServices::openUrl(target);
}

QImage LibraryService::coverImage(int number) const {
    const int index = indexOfBook(number);
    if (index < 0 || m_books.at(index).cover.isEmpty()) {
        return {};
    }
    return QImage::fromData(m_books.at(index).cover);
}

QImage LibraryService::avatarImage(const QString &username) const {
    const int index = indexOfUser(username);
    if (index < 0 || m_users.at(index).avatar.isEmpty()) {
        return {};
    }
    return QImage::fromData(m_users.at(index).avatar);
}

void LibraryService::ensureDefaultAdmin() {
    if (indexOfUser(QStringLiteral("Administrator")) >= 0) {
        return;
    }
    User admin;
    admin.username = QStringLiteral("Administrator");
    admin.displayName = QStringLiteral("Administrator");
    admin.passwordSalt = makeSalt();
    admin.passwordHash = hashPassword(QStringLiteral("114514"), admin.passwordSalt);
    admin.admin = true;
    admin.mustChangePassword = true;
    m_users.prepend(admin);
    m_prefillDefaultAdmin = true;
}

void LibraryService::migrateLegacyTextData() {
    const QString directory = locateLegacyDirectory();
    if (directory.isEmpty()) {
        return;
    }
    const QDir dir(directory);

    const QStringList usernames = readLegacyLines(dir.filePath(QStringLiteral("user.control")));
    const QStringList passwords = readLegacyLines(dir.filePath(QStringLiteral("pass.control")));
    const qsizetype userCount = std::min(usernames.size(), passwords.size());
    for (qsizetype i = 0; i < userCount; ++i) {
        const QString name = usernames.at(i).trimmed();
        if (name.isEmpty() || indexOfUser(name) >= 0) {
            continue;
        }
        User user;
        user.username = name;
        user.displayName = name;
        user.passwordSalt = makeSalt();
        user.passwordHash = hashPassword(passwords.at(i), user.passwordSalt);
        user.admin = name.compare(QStringLiteral("Administrator"), Qt::CaseInsensitive) == 0;
        user.mustChangePassword = user.admin;
        m_users.append(user);
    }

    const QStringList names = readLegacyLines(dir.filePath(QStringLiteral("name.control")));
    const QStringList authors = readLegacyLines(dir.filePath(QStringLiteral("writer.control")));
    const QStringList places = readLegacyLines(dir.filePath(QStringLiteral("state.control")));
    const QStringList publishers = readLegacyLines(dir.filePath(QStringLiteral("publisher.control")));
    const QStringList stateLines = readLegacyLines(dir.filePath(QStringLiteral("book.control")));
    const QString state = stateLines.isEmpty() ? QString() : stateLines.first();

    QHash<int, QString> owners;
    const QDir userDir(dir.filePath(QStringLiteral("user")));
    const QFileInfoList userFiles = userDir.entryInfoList({QStringLiteral("*.control")}, QDir::Files);
    for (const QFileInfo &info : userFiles) {
        const QString owner = info.completeBaseName();
        for (const QString &line : readLegacyLines(info.absoluteFilePath())) {
            bool ok = false;
            const int number = line.trimmed().toInt(&ok);
            if (ok && number > 0) {
                owners.insert(number, owner);
            }
        }
    }

    const qsizetype bookCount = std::min<qsizetype>(names.size(), 1000);
    int migratedBooks = 0;
    qint64 loanId = 1;
    for (qsizetype i = 0; i < bookCount; ++i) {
        const QString name = names.at(i).trimmed();
        if (name.isEmpty()) {
            continue;
        }
        Book book;
        book.number = kFirstBookNumber + static_cast<int>(i);
        book.name = name;
        book.author = i < authors.size() && !authors.at(i).trimmed().isEmpty()
                              ? authors.at(i).trimmed()
                              : QStringLiteral("佚名");
        book.place = i < places.size() && !places.at(i).trimmed().isEmpty()
                             ? places.at(i).trimmed()
                             : QStringLiteral("未分类");
        book.publisher = i < publishers.size() && !publishers.at(i).trimmed().isEmpty()
                                 ? publishers.at(i).trimmed()
                                 : QStringLiteral("未知");
        book.category = QStringLiteral("未分类");
        m_books.append(book);
        m_lastBookNumber = std::max(m_lastBookNumber, book.number);
        ++migratedBooks;

        if (i < state.size() && state.at(i) == QLatin1Char('1')) {
            Loan loan;
            loan.id = loanId++;
            loan.bookNumber = book.number;
            loan.username = owners.value(book.number, QStringLiteral("legacy"));
            loan.borrowedAt = QDateTime::currentDateTime();
            loan.dueAt = loan.borrowedAt.addMonths(1);
            m_loans.append(loan);
        }
    }
    refreshBookLoanState();

    if (migratedBooks > 0 || !m_users.isEmpty()) {
        m_migrationNote = QStringLiteral("已从旧版数据迁移：%1 本图书、%2 个账户")
                                  .arg(migratedBooks)
                                  .arg(m_users.size());
    }
}

QString LibraryService::locateLegacyDirectory() const {
    QStringList candidates;
    candidates << QCoreApplication::applicationDirPath();
    candidates << QDir(QCoreApplication::applicationDirPath()).absoluteFilePath(QStringLiteral("../.."));
    candidates << QDir::currentPath();

    QStringList visited;
    for (const QString &candidate : candidates) {
        const QString path = QDir::cleanPath(QFileInfo(candidate).absoluteFilePath());
        if (visited.contains(path, Qt::CaseInsensitive)) {
            continue;
        }
        visited.append(path);
        const QDir dir(path);
        if (QFileInfo::exists(dir.filePath(QStringLiteral("book.control")))
            || QFileInfo::exists(dir.filePath(QStringLiteral("user.control")))
            || QFileInfo::exists(dir.filePath(QStringLiteral("name.control")))) {
            return path;
        }
    }
    return {};
}

int LibraryService::indexOfBook(int number) const {
    for (int i = 0; i < m_books.size(); ++i) {
        if (m_books.at(i).number == number) {
            return i;
        }
    }
    return -1;
}

int LibraryService::indexOfUser(const QString &username) const {
    for (int i = 0; i < m_users.size(); ++i) {
        if (m_users.at(i).username.compare(username, Qt::CaseInsensitive) == 0) {
            return i;
        }
    }
    return -1;
}

int LibraryService::nextBookNumber() const {
    int next = kFirstBookNumber;
    for (const Book &book : m_books) {
        next = std::max(next, book.number + 1);
    }
    return next;
}

qint64 LibraryService::nextLoanId() const {
    qint64 next = 1;
    for (const Loan &loan : m_loans) {
        next = std::max(next, loan.id + 1);
    }
    return next;
}

QVariantMap LibraryService::toMap(const Book &book) const {
    const bool available = book.activeLoanId == 0;
    const bool overdue = !available && book.dueAt.isValid()
                         && book.dueAt < QDateTime::currentDateTime();
    const bool isMine = !available
                        && book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0;
    QVariantMap map;
    map.insert(QStringLiteral("number"), book.number);
    map.insert(QStringLiteral("numberText"), QString::number(book.number));
    map.insert(QStringLiteral("name"), book.name);
    map.insert(QStringLiteral("author"), book.author);
    map.insert(QStringLiteral("publisher"), book.publisher);
    map.insert(QStringLiteral("place"), book.place);
    map.insert(QStringLiteral("category"), book.category);
    map.insert(QStringLiteral("description"), book.description);
    map.insert(QStringLiteral("hasCover"), !book.cover.isEmpty());
    map.insert(QStringLiteral("available"), available);
    map.insert(QStringLiteral("availableText"), available ? QStringLiteral("在馆")
                                                          : QStringLiteral("借出"));
    map.insert(QStringLiteral("borrower"), book.borrower);
    map.insert(QStringLiteral("borrowerDisplayName"),
               available ? QString() : displayNameFor(book.borrower));
    map.insert(QStringLiteral("isMine"), isMine);
    map.insert(QStringLiteral("overdue"), overdue);
    map.insert(QStringLiteral("renewCount"), book.renewCount);
    map.insert(QStringLiteral("canRenew"), isMine && book.renewCount == 0 && !overdue);
    map.insert(QStringLiteral("activeLoanId"), book.activeLoanId);
    map.insert(QStringLiteral("borrowedAt"),
               book.borrowedAt.isValid() ? book.borrowedAt.toString(QStringLiteral("yyyy-MM-dd HH:mm"))
                                         : QString());
    map.insert(QStringLiteral("borrowedDate"), formatDay(book.borrowedAt));
    map.insert(QStringLiteral("dueDate"), formatDay(book.dueAt));
    map.insert(QStringLiteral("dueAt"),
               book.dueAt.isValid() ? book.dueAt.toString(Qt::ISODate) : QString());
    return map;
}

QVariantMap LibraryService::userMap(const User &user) const {
    const int count = activeLoanCountForUser(user.username);
    const QDateTime now = QDateTime::currentDateTime();
    const bool temporaryLocked = user.lockUntil.isValid() && user.lockUntil > now;
    int lockMinutes = 0;
    if (temporaryLocked) {
        lockMinutes = static_cast<int>((now.secsTo(user.lockUntil) + 59) / 60);
    }

    QVariantMap map;
    map.insert(QStringLiteral("username"), user.username);
    map.insert(QStringLiteral("displayName"), user.displayName.isEmpty() ? user.username
                                                                          : user.displayName);
    map.insert(QStringLiteral("admin"), user.admin);
    map.insert(QStringLiteral("roleKey"), user.admin ? QStringLiteral("admin")
                                                     : QStringLiteral("reader"));
    map.insert(QStringLiteral("borrowCount"), count);
    map.insert(QStringLiteral("blacklisted"), isUserBlacklisted(user.username));
    map.insert(QStringLiteral("locked"), user.locked);
    map.insert(QStringLiteral("temporaryLocked"), temporaryLocked);
    map.insert(QStringLiteral("lockMinutes"), lockMinutes);
    map.insert(QStringLiteral("mustChangePassword"), user.mustChangePassword);
    map.insert(QStringLiteral("hasAvatar"), !user.avatar.isEmpty());
    map.insert(QStringLiteral("isCurrent"),
               user.username.compare(m_currentUser, Qt::CaseInsensitive) == 0);
    return map;
}

QVariantMap LibraryService::loanMap(const Loan &loan) const {
    const bool returned = loan.returnedAt.isValid();
    const QDateTime end = returned ? loan.returnedAt : QDateTime::currentDateTime();
    qint64 hours = loan.borrowedAt.isValid() ? loan.borrowedAt.secsTo(end) / 3600 : 0;
    if (hours < 0) {
        hours = 0;
    }
    if (hours > std::numeric_limits<int>::max()) {
        hours = std::numeric_limits<int>::max();
    }
    const bool overdue = !returned && loan.dueAt.isValid()
                         && loan.dueAt < QDateTime::currentDateTime();

    QVariantMap map;
    map.insert(QStringLiteral("id"), loan.id);
    map.insert(QStringLiteral("bookNumber"), loan.bookNumber);
    map.insert(QStringLiteral("username"), loan.username);
    map.insert(QStringLiteral("displayName"), displayNameFor(loan.username));
    map.insert(QStringLiteral("borrowedAtIso"), loan.borrowedAt.toString(Qt::ISODate));
    map.insert(QStringLiteral("borrowedAt"), formatDate(loan.borrowedAt));
    map.insert(QStringLiteral("dueAt"), formatDate(loan.dueAt));
    map.insert(QStringLiteral("dueDate"), formatDay(loan.dueAt));
    map.insert(QStringLiteral("returnedAt"),
               returned ? formatDate(loan.returnedAt) : QString());
    map.insert(QStringLiteral("returned"), returned);
    map.insert(QStringLiteral("overdue"), overdue);
    map.insert(QStringLiteral("manualUnreturned"), loan.manualUnreturned);
    map.insert(QStringLiteral("renewCount"), loan.renewCount);
    map.insert(QStringLiteral("durationHours"), static_cast<int>(hours));
    map.insert(QStringLiteral("statusKey"),
               returned ? QStringLiteral("returned")
                        : (overdue ? QStringLiteral("overdue") : QStringLiteral("active")));
    return map;
}

QString LibraryService::fail(const QString &message) {
    setLastError(message);
    return message;
}

void LibraryService::setLastError(const QString &message) {
    if (m_lastError == message) {
        return;
    }
    m_lastError = message;
    emit lastErrorChanged();
}

void LibraryService::setStorageError(const QString &message) {
    if (m_storageError == message) {
        return;
    }
    m_storageError = message;
    emit storageChanged();
}
