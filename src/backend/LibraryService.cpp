#include "LibraryService.h"

#include "Encryption.h"

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUuid>
#include <QVariant>
#include <algorithm>

namespace {

constexpr int kDefaultBorrowLimit = 12;
constexpr int kFirstBookNumber = 1000;

QStringList readLegacyLines(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QByteArray data = file.readAll();
    QString text = QString::fromUtf8(data);
    if (text.contains(QChar(0xFFFD))) {
        // Vision 1.0 wrote its text with the system ANSI code page.
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
        if (m_books.isEmpty()) {
            migrateLegacyData();
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

bool LibraryService::createSchema() {
    const QStringList statements = {
        QStringLiteral("CREATE TABLE IF NOT EXISTS users ("
                       "id TEXT PRIMARY KEY NOT NULL,"
                       "username_enc BLOB NOT NULL,"
                       "password_enc BLOB NOT NULL,"
                       "admin_enc BLOB NOT NULL)"),
        QStringLiteral("CREATE TABLE IF NOT EXISTS books ("
                       "number INTEGER PRIMARY KEY NOT NULL,"
                       "name_enc BLOB NOT NULL,"
                       "author_enc BLOB NOT NULL,"
                       "publisher_enc BLOB NOT NULL,"
                       "place_enc BLOB NOT NULL,"
                       "borrower_enc BLOB NOT NULL,"
                       "borrowed_at_enc BLOB NOT NULL)"),
    };

    for (const QString &statement : statements) {
        QSqlQuery query(m_db);
        if (!query.exec(statement)) {
            setStorageError(QStringLiteral("创建数据库结构失败：%1").arg(query.lastError().text()));
            return false;
        }
    }

    QSqlQuery version(m_db);
    version.exec(QStringLiteral("PRAGMA user_version = 1"));
    return true;
}

bool LibraryService::loadFromDatabase() {
    m_users.clear();
    m_books.clear();
    m_lastBookNumber = 0;

    QSqlQuery usersQuery(m_db);
    if (!usersQuery.exec(QStringLiteral(
                "SELECT id, username_enc, password_enc, admin_enc FROM users ORDER BY rowid"))) {
        setStorageError(QStringLiteral("读取账户数据失败：%1").arg(usersQuery.lastError().text()));
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
        user.password = password;
        user.admin = adminText == QStringLiteral("1");
        if (!user.username.isEmpty() && indexOfUser(user.username) < 0) {
            m_users.append(user);
        }
    }

    QSqlQuery booksQuery(m_db);
    if (!booksQuery.exec(QStringLiteral(
                "SELECT number, name_enc, author_enc, publisher_enc, place_enc, "
                "borrower_enc, borrowed_at_enc FROM books ORDER BY number"))) {
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
        book.borrower = decryptText(booksQuery.value(5).toByteArray(),
                                    bookAad(book.number, "borrower"), &ok);
        if (!ok) {
            return false;
        }
        const QString borrowedAtText = decryptText(booksQuery.value(6).toByteArray(),
                                                   bookAad(book.number, "borrowedAt"), &ok);
        if (!ok) {
            return false;
        }
        book.borrowedAt = QDateTime::fromString(borrowedAtText, Qt::ISODate);
        if (book.number <= 0 || book.name.isEmpty() || indexOfBook(book.number) >= 0) {
            continue;
        }
        m_books.append(book);
        m_lastBookNumber = std::max(m_lastBookNumber, book.number);
    }
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
    if (!clear.exec(QStringLiteral("DELETE FROM books"))
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
        const QByteArray password = encryptText(user.password, userAad(uuid, "password"), &ok);
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

        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral(
                "INSERT INTO users(id, username_enc, password_enc, admin_enc) VALUES (?, ?, ?, ?)"));
        insert.addBindValue(uuid);
        insert.addBindValue(username);
        insert.addBindValue(password);
        insert.addBindValue(admin);
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
        const QByteArray publisher = encryptText(book.publisher, bookAad(book.number, "publisher"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray place = encryptText(book.place, bookAad(book.number, "place"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QByteArray borrower = encryptText(book.borrower, bookAad(book.number, "borrower"), &ok);
        if (!ok) {
            rollback();
            return false;
        }
        const QString borrowedAt = book.borrowedAt.isValid()
                                           ? book.borrowedAt.toString(Qt::ISODate)
                                           : QString();
        const QByteArray borrowedAtEnc = encryptText(borrowedAt,
                                                     bookAad(book.number, "borrowedAt"), &ok);
        if (!ok) {
            rollback();
            return false;
        }

        QSqlQuery insert(m_db);
        insert.prepare(QStringLiteral(
                "INSERT INTO books(number, name_enc, author_enc, publisher_enc, place_enc, "
                "borrower_enc, borrowed_at_enc) VALUES (?, ?, ?, ?, ?, ?, ?)"));
        insert.addBindValue(book.number);
        insert.addBindValue(name);
        insert.addBindValue(author);
        insert.addBindValue(publisher);
        insert.addBindValue(place);
        insert.addBindValue(borrower);
        insert.addBindValue(borrowedAtEnc);
        if (!insert.exec()) {
            setLastError(QStringLiteral("保存图书失败：%1").arg(insert.lastError().text()));
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

bool LibraryService::isAdmin() const {
    if (m_currentUser.isEmpty()) {
        return false;
    }
    const int index = indexOfUser(m_currentUser);
    return index >= 0 && m_users.at(index).admin;
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
        if (book.borrower.isEmpty()) {
            out.append(toMap(book));
        }
    }
    return out;
}

QVariantList LibraryService::borrowedBooks() const {
    QVariantList out;
    for (const Book &book : m_books) {
        if (!book.borrower.isEmpty()) {
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
        if (book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
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
    if (m_currentUser.isEmpty()) {
        return 0;
    }
    int count = 0;
    for (const Book &book : m_books) {
        if (book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
            ++count;
        }
    }
    return count;
}

QVariantMap LibraryService::stats() const {
    int available = 0;
    for (const Book &book : m_books) {
        if (book.borrower.isEmpty()) {
            ++available;
        }
    }
    const int mine = myBorrowCount();

    QVariantMap map;
    map.insert(QStringLiteral("totalBooks"), m_books.size());
    map.insert(QStringLiteral("availableBooks"), available);
    map.insert(QStringLiteral("borrowedBooks"), m_books.size() - available);
    map.insert(QStringLiteral("totalUsers"), m_users.size());
    map.insert(QStringLiteral("myBorrowCount"), mine);
    map.insert(QStringLiteral("myRemaining"), std::max(0, m_limit - mine));
    map.insert(QStringLiteral("borrowLimit"), m_limit);
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
    if (index < 0 || m_users.at(index).password != password) {
        fail(QStringLiteral("用户名或密码错误，请检查后重试"));
        return false;
    }

    m_currentUser = m_users.at(index).username;
    setLastError(QString());
    emit sessionChanged();
    emit booksChanged();
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
    if (m_currentUser.isEmpty()) {
        return fail(QStringLiteral("请先登录后再借阅图书"));
    }
    const int index = indexOfBook(number);
    if (index < 0) {
        return fail(QStringLiteral("未找到索书号为 %1 的图书").arg(number));
    }

    Book &book = m_books[index];
    if (!book.borrower.isEmpty()) {
        if (book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0) {
            return fail(QStringLiteral("你已借阅《%1》，请勿重复借阅").arg(book.name));
        }
        return fail(QStringLiteral("《%1》已被借出，请选择其他图书").arg(book.name));
    }
    if (myBorrowCount() >= m_limit) {
        return fail(QStringLiteral("已达到借阅上限（%1 本），请先归还部分图书").arg(m_limit));
    }

    book.borrower = m_currentUser;
    book.borrowedAt = QDateTime::currentDateTime();
    if (!persistAll()) {
        book.borrower.clear();
        book.borrowedAt = QDateTime();
        return lastError();
    }

    setLastError(QString());
    emit booksChanged();
    return {};
}

QString LibraryService::returnBook(int number) {
    if (!m_storageReady) {
        return fail(QStringLiteral("数据库不可用，无法归还：%1").arg(m_storageError));
    }
    if (m_currentUser.isEmpty()) {
        return fail(QStringLiteral("请先登录后再归还图书"));
    }
    const int index = indexOfBook(number);
    if (index < 0) {
        return fail(QStringLiteral("未找到索书号为 %1 的图书").arg(number));
    }

    Book &book = m_books[index];
    if (book.borrower.isEmpty()) {
        return fail(QStringLiteral("《%1》当前在馆，无需归还").arg(book.name));
    }
    if (book.borrower.compare(m_currentUser, Qt::CaseInsensitive) != 0) {
        return fail(QStringLiteral("《%1》并非由你借阅，无法归还").arg(book.name));
    }

    const QString previousBorrower = book.borrower;
    const QDateTime previousTime = book.borrowedAt;
    book.borrower.clear();
    book.borrowedAt = QDateTime();
    if (!persistAll()) {
        book.borrower = previousBorrower;
        book.borrowedAt = previousTime;
        return lastError();
    }

    setLastError(QString());
    emit booksChanged();
    return {};
}

QString LibraryService::addBook(const QString &name,
                                const QString &author,
                                const QString &publisher,
                                const QString &place) {
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

    Book book;
    book.number = nextBookNumber();
    book.name = bookName;
    book.author = author.trimmed().isEmpty() ? QStringLiteral("佚名") : author.trimmed();
    book.publisher = publisher.trimmed().isEmpty() ? QStringLiteral("未知") : publisher.trimmed();
    book.place = place.trimmed().isEmpty() ? QStringLiteral("未分类") : place.trimmed();

    const int previousLastNumber = m_lastBookNumber;
    m_books.append(book);
    m_lastBookNumber = book.number;
    if (!persistAll()) {
        m_books.removeLast();
        m_lastBookNumber = previousLastNumber;
        return lastError();
    }

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
    if (password.size() < 4 || password.size() > 32) {
        return fail(QStringLiteral("密码长度需为 4-32 个字符"));
    }

    User user;
    user.username = name;
    user.password = password;
    user.admin = false;
    m_users.append(user);
    if (!persistAll()) {
        m_users.removeLast();
        return lastError();
    }

    setLastError(QString());
    emit usersChanged();
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
    if (newPassword.size() < 4 || newPassword.size() > 32) {
        return fail(QStringLiteral("密码长度需为 4-32 个字符"));
    }

    const QString previous = m_users[index].password;
    m_users[index].password = newPassword;
    if (!persistAll()) {
        m_users[index].password = previous;
        return lastError();
    }

    setLastError(QString());
    emit usersChanged();
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
    for (const Book &book : m_books) {
        if (book.borrower.compare(user.username, Qt::CaseInsensitive) == 0) {
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
    };

    static const SeedBook seeds[] = {
        {"红楼梦", "曹雪芹", "人民文学出版社", "A 区 · 01 架"},
        {"西游记", "吴承恩", "人民文学出版社", "A 区 · 02 架"},
        {"水浒传", "施耐庵", "人民文学出版社", "A 区 · 03 架"},
        {"三国演义", "罗贯中", "人民文学出版社", "A 区 · 04 架"},
        {"活着", "余华", "作家出版社", "B 区 · 01 架"},
        {"平凡的世界", "路遥", "北京十月文艺出版社", "B 区 · 02 架"},
        {"百年孤独", "加西亚·马尔克斯", "南海出版公司", "C 区 · 01 架"},
        {"小王子", "安托万·德·圣埃克苏佩里", "人民文学出版社", "C 区 · 02 架"},
        {"人类简史", "尤瓦尔·赫拉利", "中信出版社", "D 区 · 01 架"},
        {"代码大全", "史蒂夫·迈克康奈尔", "电子工业出版社", "E 区 · 01 架"},
        {"Qt 6 C++ 开发指南", "王维波", "人民邮电出版社", "E 区 · 02 架"},
        {"深入理解计算机系统", "Randal E. Bryant", "机械工业出版社", "E 区 · 03 架"},
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
            default:
                match = book.name.contains(key, Qt::CaseInsensitive)
                        || book.author.contains(key, Qt::CaseInsensitive)
                        || book.publisher.contains(key, Qt::CaseInsensitive)
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

void LibraryService::ensureDefaultAdmin() {
    if (indexOfUser(QStringLiteral("Administrator")) >= 0) {
        return;
    }
    User admin;
    admin.username = QStringLiteral("Administrator");
    admin.password = QStringLiteral("114514");
    admin.admin = true;
    m_users.prepend(admin);
}

void LibraryService::migrateLegacyData() {
    const QString directory = locateLegacyDirectory();
    if (directory.isEmpty()) {
        return;
    }
    const QDir dir(directory);

    // 账户：user.control 与 pass.control 逐行对应。
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
        user.password = passwords.at(i);
        user.admin = name.compare(QStringLiteral("Administrator"), Qt::CaseInsensitive) == 0;
        m_users.append(user);
    }

    // 图书：name/writer/state/publisher.control 共用行号，索书号从 1000 开始。
    const QStringList names = readLegacyLines(dir.filePath(QStringLiteral("name.control")));
    const QStringList authors = readLegacyLines(dir.filePath(QStringLiteral("writer.control")));
    const QStringList places = readLegacyLines(dir.filePath(QStringLiteral("state.control")));
    const QStringList publishers = readLegacyLines(dir.filePath(QStringLiteral("publisher.control")));
    const QStringList stateLines = readLegacyLines(dir.filePath(QStringLiteral("book.control")));
    const QString state = stateLines.isEmpty() ? QString() : stateLines.first();

    // 旧版每个账户的借阅清单保存在 user/<username>.control 中。
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
        if (i < state.size() && state.at(i) == QLatin1Char('1')) {
            book.borrower = owners.value(book.number, QStringLiteral("legacy"));
        }
        m_books.append(book);
        m_lastBookNumber = std::max(m_lastBookNumber, book.number);
        ++migratedBooks;
    }

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

QVariantMap LibraryService::toMap(const Book &book) const {
    const bool available = book.borrower.isEmpty();
    QVariantMap map;
    map.insert(QStringLiteral("number"), book.number);
    map.insert(QStringLiteral("numberText"), QString::number(book.number));
    map.insert(QStringLiteral("name"), book.name);
    map.insert(QStringLiteral("author"), book.author);
    map.insert(QStringLiteral("publisher"), book.publisher);
    map.insert(QStringLiteral("place"), book.place);
    map.insert(QStringLiteral("available"), available);
    map.insert(QStringLiteral("availableText"), available ? QStringLiteral("在馆")
                                                          : QStringLiteral("借出"));
    map.insert(QStringLiteral("borrower"), book.borrower);
    map.insert(QStringLiteral("isMine"),
               !available && book.borrower.compare(m_currentUser, Qt::CaseInsensitive) == 0);
    map.insert(QStringLiteral("borrowedAt"),
               book.borrowedAt.isValid() ? book.borrowedAt.toString(QStringLiteral("yyyy-MM-dd HH:mm"))
                                         : QString());
    map.insert(QStringLiteral("borrowedDate"),
               book.borrowedAt.isValid() ? book.borrowedAt.toString(QStringLiteral("yyyy-MM-dd"))
                                         : QString());
    map.insert(QStringLiteral("dueDate"),
               book.borrowedAt.isValid()
                       ? book.borrowedAt.addDays(30).toString(QStringLiteral("yyyy-MM-dd"))
                       : QString());
    return map;
}

QVariantMap LibraryService::userMap(const User &user) const {
    int count = 0;
    for (const Book &book : m_books) {
        if (book.borrower.compare(user.username, Qt::CaseInsensitive) == 0) {
            ++count;
        }
    }

    QVariantMap map;
    map.insert(QStringLiteral("username"), user.username);
    map.insert(QStringLiteral("password"), user.password);
    map.insert(QStringLiteral("admin"), user.admin);
    map.insert(QStringLiteral("role"), user.admin ? QStringLiteral("管理员") : QStringLiteral("读者"));
    map.insert(QStringLiteral("borrowCount"), count);
    map.insert(QStringLiteral("isCurrent"),
               user.username.compare(m_currentUser, Qt::CaseInsensitive) == 0);
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
