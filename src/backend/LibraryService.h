#pragma once

#include <QDateTime>
#include <QImage>
#include <QList>
#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * @brief 图书管理系统的数据与业务核心。
 *
 * 负责账户、图书、借阅历史的内存模型与 SQLite 持久化，并通过 QML 单例
 * “LibraryService” 暴露给界面层。用户与图书的文本字段在写入数据库前
 * 使用 AES-256-GCM 独立加密，主密钥由 Windows DPAPI 保护；密码只保存
 * PBKDF2-HMAC-SHA256 哈希，管理员无法查看原始密码。
 */
class LibraryService : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY sessionChanged)
    Q_PROPERTY(QString currentUsername READ currentUsername NOTIFY sessionChanged)
    Q_PROPERTY(QString currentDisplayName READ currentDisplayName NOTIFY sessionChanged)
    Q_PROPERTY(bool currentHasAvatar READ currentHasAvatar NOTIFY sessionChanged)
    Q_PROPERTY(bool isAdmin READ isAdmin NOTIFY sessionChanged)
    Q_PROPERTY(bool mustChangePassword READ mustChangePassword NOTIFY sessionChanged)
    Q_PROPERTY(bool prefillDefaultAdmin READ prefillDefaultAdmin NOTIFY usersChanged)
    Q_PROPERTY(bool blacklisted READ blacklisted NOTIFY booksChanged)
    Q_PROPERTY(QVariantList books READ books NOTIFY booksChanged)
    Q_PROPERTY(QVariantList availableBooks READ availableBooks NOTIFY booksChanged)
    Q_PROPERTY(QVariantList borrowedBooks READ borrowedBooks NOTIFY booksChanged)
    Q_PROPERTY(QVariantList myBorrowedBooks READ myBorrowedBooks NOTIFY booksChanged)
    Q_PROPERTY(QVariantList users READ users NOTIFY usersChanged)
    Q_PROPERTY(int borrowLimit READ borrowLimit CONSTANT)
    Q_PROPERTY(int myBorrowCount READ myBorrowCount NOTIFY booksChanged)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY booksChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(QString databasePath READ databasePath CONSTANT)
    Q_PROPERTY(bool storageReady READ storageReady NOTIFY storageChanged)
    Q_PROPERTY(QString storageError READ storageError NOTIFY storageChanged)
    Q_PROPERTY(QString migrationNote READ migrationNote NOTIFY migrationNoteChanged)
    Q_PROPERTY(int lastBookNumber READ lastBookNumber NOTIFY booksChanged)
    Q_PROPERTY(int imageRevision READ imageRevision NOTIFY imageRevisionChanged)

public:
    explicit LibraryService(QObject *parent = nullptr);
    ~LibraryService() override;

    bool isLoggedIn() const { return !m_currentUser.isEmpty(); }
    QString currentUsername() const { return m_currentUser; }
    QString currentDisplayName() const;
    bool currentHasAvatar() const;
    bool isAdmin() const;
    bool mustChangePassword() const;
    bool prefillDefaultAdmin() const { return m_prefillDefaultAdmin; }
    bool blacklisted() const;
    QVariantList books() const;
    QVariantList availableBooks() const;
    QVariantList borrowedBooks() const;
    QVariantList myBorrowedBooks() const;
    QVariantList users() const;
    int borrowLimit() const { return m_limit; }
    int myBorrowCount() const;
    QVariantMap stats() const;
    QString lastError() const { return m_lastError; }
    QString databasePath() const { return m_databasePath; }
    bool storageReady() const { return m_storageReady; }
    QString storageError() const { return m_storageError; }
    QString migrationNote() const { return m_migrationNote; }
    int lastBookNumber() const { return m_lastBookNumber; }
    int imageRevision() const { return m_imageRevision; }

    Q_INVOKABLE bool login(const QString &username, const QString &password);
    Q_INVOKABLE void logout();

    Q_INVOKABLE QString borrowBook(int number);
    Q_INVOKABLE QString returnBook(int number);
    Q_INVOKABLE QString renewBook(int number);
    Q_INVOKABLE QString adminReturnLoan(qint64 loanId);
    Q_INVOKABLE QString adminMarkUnreturned(qint64 loanId);
    Q_INVOKABLE QVariantList bookLoans(int number) const;

    Q_INVOKABLE QString addBook(const QString &name,
                                const QString &author,
                                const QString &publisher,
                                const QString &place,
                                const QString &description,
                                const QString &category,
                                const QString &coverPath);
    Q_INVOKABLE QString addUser(const QString &username, const QString &password);
    Q_INVOKABLE QString resetPassword(const QString &username, const QString &newPassword);
    Q_INVOKABLE QString changeOwnPassword(const QString &newPassword);
    Q_INVOKABLE QString updateProfile(const QString &displayName,
                                      const QString &username,
                                      const QString &avatarPath,
                                      bool clearAvatar);
    Q_INVOKABLE QString setUserLocked(const QString &username, bool locked);
    Q_INVOKABLE QString removeUser(const QString &username);
    Q_INVOKABLE int seedSampleBooks();

    Q_INVOKABLE QVariantList searchBooks(const QString &keyword, int mode = 0) const;
    Q_INVOKABLE QVariantMap findBook(int number) const;

    Q_INVOKABLE bool openExternalUrl(const QString &url);
    QImage coverImage(int number) const;
    QImage avatarImage(const QString &username) const;

signals:
    void sessionChanged();
    void booksChanged();
    void usersChanged();
    void lastErrorChanged();
    void storageChanged();
    void migrationNoteChanged();
    void imageRevisionChanged();

private:
    struct Book {
        int number = 0;
        QString name;
        QString author;
        QString publisher;
        QString place;
        QString category;
        QString description;
        QByteArray cover;

        QString borrower;
        QDateTime borrowedAt;
        QDateTime dueAt;
        int renewCount = 0;
        qint64 activeLoanId = 0;
    };

    struct User {
        QString username;
        QString displayName;
        QByteArray passwordHash; // hex
        QByteArray passwordSalt;
        bool admin = false;
        bool mustChangePassword = false;
        bool locked = false;
        int failedAttempts = 0;
        QDateTime lockUntil;
        QByteArray avatar;
    };

    struct Loan {
        qint64 id = 0;
        int bookNumber = 0;
        QString username;
        QDateTime borrowedAt;
        QDateTime dueAt;
        QDateTime returnedAt;
        int renewCount = 0;
        bool manualUnreturned = false;
    };

    bool initializeStorage();
    bool openDatabase();
    bool createSchema();
    bool migrateV1ToV2();
    bool loadFromDatabase();
    bool persistAll();
    void closeDatabase();
    int schemaVersion();

    QByteArray encryptText(const QString &text, const QByteArray &aad, bool *ok);
    QByteArray encryptBlob(const QByteArray &data, const QByteArray &aad, bool *ok);
    QString decryptText(const QByteArray &blob, const QByteArray &aad, bool *ok);
    QByteArray decryptBlob(const QByteArray &blob, const QByteArray &aad, bool *ok);
    QByteArray bookAad(int number, const char *field) const;
    QByteArray userAad(const QString &uuid, const char *field) const;
    QByteArray loanAad(qint64 id, const char *field) const;

    static QByteArray makeSalt();
    static QByteArray hashPassword(const QString &password, const QByteArray &salt);
    static bool verifyPassword(const QString &password, const QByteArray &hash,
                               const QByteArray &salt);
    static QString validatePasswordStrength(const QString &password);

    void refreshBookLoanState();
    void bumpImageRevision();
    bool isUserBlacklisted(const QString &username) const;
    int activeLoanCountForUser(const QString &username) const;
    int activeLoanIndexForBook(int number) const;
    int loanIndexById(qint64 id) const;
    QDateTime nextDueDate(const QDateTime &from) const;
    QString displayNameFor(const QString &username) const;

    void ensureDefaultAdmin();
    void migrateLegacyTextData();
    QString locateLegacyDirectory() const;
    int indexOfBook(int number) const;
    int indexOfUser(const QString &username) const;
    int nextBookNumber() const;
    qint64 nextLoanId() const;
    QVariantMap toMap(const Book &book) const;
    QVariantMap userMap(const User &user) const;
    QVariantMap loanMap(const Loan &loan) const;
    QString fail(const QString &message);
    void setLastError(const QString &message);
    void setStorageError(const QString &message);

    QList<Book> m_books;
    QList<User> m_users;
    QList<Loan> m_loans;
    QString m_currentUser;
    int m_limit = 12;
    QString m_lastError;
    QString m_databasePath;
    QString m_keyPath;
    QString m_connectionName;
    QSqlDatabase m_db;
    bool m_storageReady = false;
    QString m_storageError;
    QString m_migrationNote;
    int m_lastBookNumber = 0;
    int m_imageRevision = 1;
    bool m_prefillDefaultAdmin = false;
};
