#include "Encryption.h"

#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSaveFile>

#include <cstring>

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <bcrypt.h>
#include <wincrypt.h>

namespace {

constexpr char kKeyMagic[] = "LMSK1";
constexpr int kKeySize = 32;
constexpr int kNonceSize = 12;
constexpr int kTagSize = 16;
constexpr quint8 kBlobVersion = 0x01;

QString windowsError(quint32 code) {
    return QStringLiteral("Windows 错误 0x%1").arg(code, 8, 16, QLatin1Char('0'));
}

bool protectKey(const QByteArray &key, QByteArray *protectedKey, QString *error) {
    DATA_BLOB input{static_cast<DWORD>(key.size()),
                    reinterpret_cast<BYTE *>(const_cast<char *>(key.constData()))};
    DATA_BLOB entropy{sizeof(kKeyMagic) - 1,
                      reinterpret_cast<BYTE *>(const_cast<char *>(kKeyMagic))};
    DATA_BLOB output{};
    if (!CryptProtectData(&input,
                          L"LibraryManagementSystem master key",
                          &entropy,
                          nullptr,
                          nullptr,
                          CRYPTPROTECT_UI_FORBIDDEN,
                          &output)) {
        if (error) {
            *error = QStringLiteral("DPAPI 加密主密钥失败：%1").arg(windowsError(GetLastError()));
        }
        return false;
    }
    *protectedKey = QByteArray(reinterpret_cast<const char *>(output.pbData),
                               static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return true;
}

bool unprotectKey(const QByteArray &protectedKey, QByteArray *key, QString *error) {
    DATA_BLOB input{static_cast<DWORD>(protectedKey.size()),
                    reinterpret_cast<BYTE *>(const_cast<char *>(protectedKey.constData()))};
    DATA_BLOB entropy{sizeof(kKeyMagic) - 1,
                      reinterpret_cast<BYTE *>(const_cast<char *>(kKeyMagic))};
    DATA_BLOB output{};
    if (!CryptUnprotectData(&input,
                            nullptr,
                            &entropy,
                            nullptr,
                            nullptr,
                            CRYPTPROTECT_UI_FORBIDDEN,
                            &output)) {
        if (error) {
            *error = QStringLiteral("无法用当前 Windows 用户解密主密钥（library.key 不属于本机当前用户，或文件已损坏）");
        }
        return false;
    }
    *key = QByteArray(reinterpret_cast<const char *>(output.pbData),
                      static_cast<int>(output.cbData));
    LocalFree(output.pbData);
    return true;
}

} // namespace

Encryption &Encryption::instance() {
    static Encryption encryption;
    return encryption;
}

Encryption::~Encryption() {
    cleanup();
}

bool Encryption::init(const QString &keyFilePath, bool databaseExists, QString *error) {
    cleanup();
    m_key.clear();

    if (QFileInfo::exists(keyFilePath)) {
        if (!loadKey(keyFilePath, error)) {
            return false;
        }
    } else {
        if (databaseExists) {
            if (error) {
                *error = QStringLiteral("数据库已存在，但加密密钥文件 library.key 缺失，无法解密数据");
            }
            return false;
        }
        if (!createKey(keyFilePath, error)) {
            return false;
        }
    }

    return setupKey(error);
}

bool Encryption::loadKey(const QString &keyFilePath, QString *error) {
    QFile file(keyFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) {
            *error = QStringLiteral("无法读取密钥文件：%1").arg(file.errorString());
        }
        return false;
    }
    const QByteArray data = file.readAll();
    if (data.size() <= static_cast<int>(sizeof(kKeyMagic) - 1)
        || data.left(sizeof(kKeyMagic) - 1) != QByteArray(kKeyMagic, sizeof(kKeyMagic) - 1)) {
        if (error) {
            *error = QStringLiteral("密钥文件格式无效");
        }
        return false;
    }

    QByteArray key;
    if (!unprotectKey(data.mid(sizeof(kKeyMagic) - 1), &key, error)) {
        return false;
    }
    if (key.size() != kKeySize) {
        if (error) {
            *error = QStringLiteral("密钥长度无效");
        }
        return false;
    }
    m_key = key;
    return true;
}

bool Encryption::createKey(const QString &keyFilePath, QString *error) {
    QByteArray key(kKeySize, '\0');
    for (int i = 0; i < kKeySize; i += 4) {
        const quint32 value = QRandomGenerator::system()->generate();
        std::memcpy(key.data() + i, &value, 4);
    }

    QByteArray protectedKey;
    if (!protectKey(key, &protectedKey, error)) {
        return false;
    }

    QSaveFile file(keyFilePath);
    if (!file.open(QIODevice::WriteOnly)) {
        if (error) {
            *error = QStringLiteral("无法创建密钥文件：%1").arg(file.errorString());
        }
        return false;
    }
    file.write(kKeyMagic, sizeof(kKeyMagic) - 1);
    file.write(protectedKey);
    if (!file.commit()) {
        if (error) {
            *error = QStringLiteral("保存密钥文件失败：%1").arg(file.errorString());
        }
        return false;
    }
    QFile::setPermissions(keyFilePath, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    m_key = key;
    return true;
}

bool Encryption::setupKey(QString *error) {
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    NTSTATUS status = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_AES_ALGORITHM, nullptr, 0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("无法初始化 AES 加密算法：%1").arg(windowsError(static_cast<quint32>(status)));
        }
        return false;
    }

    status = BCryptSetProperty(algorithm,
                               BCRYPT_CHAINING_MODE,
                               reinterpret_cast<PUCHAR>(const_cast<wchar_t *>(BCRYPT_CHAIN_MODE_GCM)),
                               sizeof(BCRYPT_CHAIN_MODE_GCM),
                               0);
    if (!BCRYPT_SUCCESS(status)) {
        BCryptCloseAlgorithmProvider(algorithm, 0);
        if (error) {
            *error = QStringLiteral("无法启用 AES-GCM 模式：%1").arg(windowsError(static_cast<quint32>(status)));
        }
        return false;
    }

    BCRYPT_KEY_HANDLE keyHandle = nullptr;
    status = BCryptGenerateSymmetricKey(algorithm,
                                        &keyHandle,
                                        nullptr,
                                        0,
                                        reinterpret_cast<PUCHAR>(m_key.data()),
                                        static_cast<ULONG>(m_key.size()),
                                        0);
    if (!BCRYPT_SUCCESS(status)) {
        BCryptCloseAlgorithmProvider(algorithm, 0);
        if (error) {
            *error = QStringLiteral("无法创建 AES 密钥句柄：%1").arg(windowsError(static_cast<quint32>(status)));
        }
        return false;
    }

    m_alg = algorithm;
    m_keyHandle = keyHandle;
    return true;
}

QByteArray Encryption::encrypt(const QByteArray &plaintext, const QByteArray &aad, QString *error) const {
    if (!isReady()) {
        if (error) {
            *error = QStringLiteral("加密服务尚未初始化");
        }
        return {};
    }

    QByteArray nonce(kNonceSize, '\0');
    for (int i = 0; i < kNonceSize; i += 4) {
        const quint32 value = QRandomGenerator::system()->generate();
        std::memcpy(nonce.data() + i, &value, 4);
    }
    QByteArray tag(kTagSize, '\0');

    BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo;
    BCRYPT_INIT_AUTH_MODE_INFO(authInfo);
    authInfo.pbNonce = reinterpret_cast<PUCHAR>(nonce.data());
    authInfo.cbNonce = static_cast<ULONG>(nonce.size());
    authInfo.pbAuthData = aad.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(aad.constData()));
    authInfo.cbAuthData = static_cast<ULONG>(aad.size());
    authInfo.pbTag = reinterpret_cast<PUCHAR>(tag.data());
    authInfo.cbTag = static_cast<ULONG>(tag.size());

    BCRYPT_KEY_HANDLE keyHandle = static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle);
    ULONG resultSize = 0;
    NTSTATUS status = BCryptEncrypt(keyHandle,
                                    plaintext.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(plaintext.constData())),
                                    static_cast<ULONG>(plaintext.size()),
                                    &authInfo,
                                    nullptr,
                                    0,
                                    nullptr,
                                    0,
                                    &resultSize,
                                    0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("加密字段失败：%1").arg(windowsError(static_cast<quint32>(status)));
        }
        return {};
    }

    QByteArray cipherText(static_cast<int>(resultSize), '\0');
    status = BCryptEncrypt(keyHandle,
                           plaintext.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(plaintext.constData())),
                           static_cast<ULONG>(plaintext.size()),
                           &authInfo,
                           nullptr,
                           0,
                           resultSize == 0 ? nullptr : reinterpret_cast<PUCHAR>(cipherText.data()),
                           static_cast<ULONG>(cipherText.size()),
                           &resultSize,
                           0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("加密字段失败：%1").arg(windowsError(static_cast<quint32>(status)));
        }
        return {};
    }
    cipherText.truncate(static_cast<int>(resultSize));

    QByteArray blob;
    blob.reserve(1 + nonce.size() + tag.size() + cipherText.size());
    blob.append(static_cast<char>(kBlobVersion));
    blob.append(nonce);
    blob.append(tag);
    blob.append(cipherText);
    return blob;
}

QByteArray Encryption::decrypt(const QByteArray &blob, const QByteArray &aad, QString *error) const {
    if (!isReady()) {
        if (error) {
            *error = QStringLiteral("加密服务尚未初始化");
        }
        return {};
    }
    if (blob.size() < 1 + kNonceSize + kTagSize
        || static_cast<quint8>(blob.at(0)) != kBlobVersion) {
        if (error) {
            *error = QStringLiteral("密文格式无效");
        }
        return {};
    }

    const QByteArray nonce = blob.mid(1, kNonceSize);
    const QByteArray tag = blob.mid(1 + kNonceSize, kTagSize);
    const QByteArray cipherText = blob.mid(1 + kNonceSize + kTagSize);

    BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo;
    BCRYPT_INIT_AUTH_MODE_INFO(authInfo);
    authInfo.pbNonce = reinterpret_cast<PUCHAR>(const_cast<char *>(nonce.constData()));
    authInfo.cbNonce = static_cast<ULONG>(nonce.size());
    authInfo.pbAuthData = aad.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(aad.constData()));
    authInfo.cbAuthData = static_cast<ULONG>(aad.size());
    authInfo.pbTag = reinterpret_cast<PUCHAR>(const_cast<char *>(tag.constData()));
    authInfo.cbTag = static_cast<ULONG>(tag.size());

    BCRYPT_KEY_HANDLE keyHandle = static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle);
    ULONG resultSize = 0;
    NTSTATUS status = BCryptDecrypt(keyHandle,
                                    cipherText.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(cipherText.constData())),
                                    static_cast<ULONG>(cipherText.size()),
                                    &authInfo,
                                    nullptr,
                                    0,
                                    nullptr,
                                    0,
                                    &resultSize,
                                    0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("字段完整性校验失败，数据可能被篡改或密钥不匹配");
        }
        return {};
    }

    QByteArray plainText(static_cast<int>(resultSize), '\0');
    status = BCryptDecrypt(keyHandle,
                           cipherText.isEmpty() ? nullptr : reinterpret_cast<PUCHAR>(const_cast<char *>(cipherText.constData())),
                           static_cast<ULONG>(cipherText.size()),
                           &authInfo,
                           nullptr,
                           0,
                           resultSize == 0 ? nullptr : reinterpret_cast<PUCHAR>(plainText.data()),
                           static_cast<ULONG>(plainText.size()),
                           &resultSize,
                           0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("字段完整性校验失败，数据可能被篡改或密钥不匹配");
        }
        return {};
    }
    plainText.truncate(static_cast<int>(resultSize));
    return plainText;
}

void Encryption::cleanup() {
    if (m_keyHandle) {
        BCryptDestroyKey(static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle));
        m_keyHandle = nullptr;
    }
    if (m_alg) {
        BCryptCloseAlgorithmProvider(static_cast<BCRYPT_ALG_HANDLE>(m_alg), 0);
        m_alg = nullptr;
    }
    m_key.clear();
}
