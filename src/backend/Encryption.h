#pragma once

#include <QByteArray>
#include <QString>

/**
 * @brief 跨平台字段加密（AES-256-GCM）。
 *
 * Windows 使用 DPAPI 保护主密钥；macOS / Linux / HarmonyOS 目前使用
 * 仅当前用户可读写的 library.key（0600）。数据库中的每个字段独立加密：
 *   0x01 | 12 字节 nonce | 16 字节认证标签 | 密文
 * AAD 绑定“表/记录/字段”，防止密文在不同字段之间被替换。
 */
class Encryption {
public:
    static Encryption &instance();

    bool init(const QString &keyFilePath, bool databaseExists, QString *error);
    bool isReady() const {
#ifdef Q_OS_WIN
        return !m_key.isEmpty() && m_alg != nullptr && m_keyHandle != nullptr;
#else
        return !m_key.isEmpty();
#endif
    }

    QByteArray encrypt(const QByteArray &plaintext, const QByteArray &aad,
                       QString *error = nullptr) const;
    QByteArray decrypt(const QByteArray &blob, const QByteArray &aad,
                       QString *error = nullptr) const;

private:
    Encryption() = default;
    ~Encryption();
    Encryption(const Encryption &) = delete;
    Encryption &operator=(const Encryption &) = delete;

    bool loadKey(const QString &keyFilePath, QString *error);
    bool createKey(const QString &keyFilePath, QString *error);
    bool setupKey(QString *error);
    void cleanup();

    QByteArray m_key;
    void *m_alg = nullptr;
    void *m_keyHandle = nullptr;
};
