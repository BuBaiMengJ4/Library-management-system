#pragma once

#include <QByteArray>
#include <QString>

/**
 * @brief Windows DPAPI + AES-256-GCM 字段加密。
 *
 * 数据库主密钥由系统随机生成，并通过 DPAPI 以当前 Windows 用户为范围
 * 保护后写入 library.key。只有同一用户在同一台机器上才能解出主密钥。
 *
 * 每个字段独立加密，密文格式为：
 *   0x01 | 12 字节 nonce | 16 字节认证标签 | 密文
 * AAD 绑定“表/记录/字段”，防止密文在不同字段之间被替换。
 */
class Encryption {
public:
    static Encryption &instance();

    bool init(const QString &keyFilePath, bool databaseExists, QString *error);
    bool isReady() const { return !m_key.isEmpty() && m_alg != nullptr && m_keyHandle != nullptr; }

    QByteArray encrypt(const QByteArray &plaintext, const QByteArray &aad, QString *error = nullptr) const;
    QByteArray decrypt(const QByteArray &blob, const QByteArray &aad, QString *error = nullptr) const;

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
