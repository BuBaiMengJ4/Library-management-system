#pragma once

#include <QDateTime>
#include <QList>
#include <QObject>
#include <QSqlDatabase>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * @brief 图书管理系统的数据与业务核心。
 *
 * 负责账户、图书、借阅记录的内存模型与 SQLite 持久化，并通过 QML 单例
 * “LibraryService” 暴露给界面层。用户与图书的文本字段在写入数据库前
 * 使用 AES-256-GCM 独立加密，主密钥由 Windows DPAPI 保护。
 */
class LibraryService : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentUsername READ currentUsername NOTIFY sessionChanged)
    Q_PROPERTY(bool isAdmin READ isAdmin NOTIFY sessionChanged)
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

public:
    explicit LibraryService(QObject *parent = nullptr);
    ~LibraryService() override;

    QString currentUsername() const { return m_currentUser; }
    bool isAdmin() const;
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

    Q_INVOKABLE bool login(const QString &username, const QString &password);
    Q_INVOKABLE void logout();

    Q_INVOKABLE QString borrowBook(int number);
    Q_INVOKABLE QString returnBook(int number);

    Q_INVOKABLE QString addBook(const QString &name,
                                const QString &author,
                                const QString &publisher,
                                const QString &place);
    Q_INVOKABLE QString addUser(const QString &username, const QString &password);
    Q_INVOKABLE QString resetPassword(const QString &username, const QString &newPassword);
    Q_INVOKABLE QString removeUser(const QString &username);
    Q_INVOKABLE int seedSampleBooks();

    Q_INVOKABLE QVariantList searchBooks(const QString &keyword, int mode = 0) const;
    Q_INVOKABLE QVariantMap findBook(int number) const;

signals:
    void sessionChanged();
    void booksChanged();
    void usersChanged();
    void lastErrorChanged();
    void storageChanged();
    void migrationNoteChanged();

private:
    struct Book {
        int number = 0;
        QString name;
        QString author;
        QString publisher;
        QString place;
        QString borrower;
        QDateTime borrowedAt;
    };

    struct User {
        QString username;
        QString password;
        bool admin = false;
    };

    bool initializeStorage();
    bool openDatabase();
    bool createSchema();
    bool loadFromDatabase();
    bool persistAll();
    void closeDatabase();

    QByteArray encryptText(const QString &text, const QByteArray &aad, bool *ok);
    QString decryptText(const QByteArray &blob, const QByteArray &aad, bool *ok);
    QByteArray bookAad(int number, const char *field) const;
    QByteArray userAad(const QString &uuid, const char *field) const;

    void ensureDefaultAdmin();
    void migrateLegacyData();
    QString locateLegacyDirectory() const;
    int indexOfBook(int number) const;
    int indexOfUser(const QString &username) const;
    int nextBookNumber() const;
    QVariantMap toMap(const Book &book) const;
    QVariantMap userMap(const User &user) const;
    QString fail(const QString &message);
    void setLastError(const QString &message);
    void setStorageError(const QString &message);

    QList<Book> m_books;
    QList<User> m_users;
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
};
