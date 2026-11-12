#include "Encryption.h"

#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QSaveFile>

#include <cstring>

#ifdef Q_OS_WIN
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  include <windows.h>
#  include <bcrypt.h>
#  include <wincrypt.h>
#else
#  include <openssl/evp.h>
#  include <openssl/rand.h>
#endif

namespace {

constexpr char kWindowsMagic[] = "LMSK1";
constexpr char kPortableMagic[] = "LMSK2";
constexpr int kKeySize = 32;
constexpr int kNonceSize = 12;
constexpr int kTagSize = 16;
constexpr quint8 kBlobVersion = 0x01;

#ifdef Q_OS_WIN
QString windowsError(quint32 code) {
    return QStringLiteral("Windows 错误 0x%1").arg(code, 8, 16, QLatin1Char('0'));
}

bool protectKey(const QByteArray &key, QByteArray *protectedKey, QString *error) {
    DATA_BLOB input{static_cast<DWORD>(key.size()),
                    reinterpret_cast<BYTE *>(const_cast<char *>(key.constData()))};
    DATA_BLOB entropy{sizeof(kWindowsMagic) - 1,
                      reinterpret_cast<BYTE *>(const_cast<char *>(kWindowsMagic))};
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
    DATA_BLOB entropy{sizeof(kWindowsMagic) - 1,
                      reinterpret_cast<BYTE *>(const_cast<char *>(kWindowsMagic))};
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
#else
bool protectKey(const QByteArray &key, QByteArray *protectedKey, QString *error) {
    Q_UNUSED(error)
    *protectedKey = key;
    return true;
}

bool unprotectKey(const QByteArray &protectedKey, QByteArray *key, QString *error) {
    Q_UNUSED(error)
    *key = protectedKey;
    return true;
}
#endif

QByteArray randomBytes(int size) {
    QByteArray bytes(size, '\0');
    for (int i = 0; i < size; i += 4) {
        const quint32 value = QRandomGenerator::system()->generate();
        const int count = qMin(4, size - i);
        std::memcpy(bytes.data() + i, &value, static_cast<size_t>(count));
    }
    return bytes;
}

#ifndef Q_OS_WIN
bool opensslEncrypt(const QByteArray &key,
                    const QByteArray &nonce,
                    const QByteArray &aad,
                    const QByteArray &plainText,
                    QByteArray *cipherText,
                    QByteArray *tag,
                    QString *error) {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        if (error) {
            *error = QStringLiteral("无法创建 OpenSSL 加密上下文");
        }
        return false;
    }
    bool ok = false;
    int length = 0;
    int total = 0;
    QByteArray output(plainText.size() + EVP_CIPHER_block_size(EVP_aes_256_gcm()), '\0');
    do {
        if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1) {
            break;
        }
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) != 1) {
            break;
        }
        if (EVP_EncryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               reinterpret_cast<const unsigned char *>(nonce.constData()))
            != 1) {
            break;
        }
        if (!aad.isEmpty()
            && EVP_EncryptUpdate(ctx, nullptr, &length,
                                 reinterpret_cast<const unsigned char *>(aad.constData()),
                                 aad.size())
                   != 1) {
            break;
        }
        if (!plainText.isEmpty()
            && EVP_EncryptUpdate(ctx,
                                 reinterpret_cast<unsigned char *>(output.data()), &length,
                                 reinterpret_cast<const unsigned char *>(plainText.constData()),
                                 plainText.size())
                   != 1) {
            break;
        }
        total = plainText.isEmpty() ? 0 : length;
        if (EVP_EncryptFinal_ex(ctx,
                                reinterpret_cast<unsigned char *>(output.data()) + total,
                                &length)
            != 1) {
            break;
        }
        total += length;
        QByteArray tagBuffer(kTagSize, '\0');
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, kTagSize, tagBuffer.data()) != 1) {
            break;
        }
        output.truncate(total);
        *cipherText = output;
        *tag = tagBuffer;
        ok = true;
    } while (false);
    EVP_CIPHER_CTX_free(ctx);
    if (!ok && error) {
        *error = QStringLiteral("AES-GCM 加密失败");
    }
    return ok;
}

bool opensslDecrypt(const QByteArray &key,
                    const QByteArray &nonce,
                    const QByteArray &aad,
                    const QByteArray &cipherText,
                    const QByteArray &tag,
                    QByteArray *plainText,
                    QString *error) {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        if (error) {
            *error = QStringLiteral("无法创建 OpenSSL 解密上下文");
        }
        return false;
    }
    bool ok = false;
    int length = 0;
    int total = 0;
    QByteArray output(cipherText.size() + EVP_CIPHER_block_size(EVP_aes_256_gcm()), '\0');
    do {
        if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) != 1) {
            break;
        }
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, nonce.size(), nullptr) != 1) {
            break;
        }
        if (EVP_DecryptInit_ex(ctx, nullptr, nullptr,
                               reinterpret_cast<const unsigned char *>(key.constData()),
                               reinterpret_cast<const unsigned char *>(nonce.constData()))
            != 1) {
            break;
        }
        if (!aad.isEmpty()
            && EVP_DecryptUpdate(ctx, nullptr, &length,
                                 reinterpret_cast<const unsigned char *>(aad.constData()),
                                 aad.size())
                   != 1) {
            break;
        }
        if (!cipherText.isEmpty()
            && EVP_DecryptUpdate(ctx,
                                 reinterpret_cast<unsigned char *>(output.data()), &length,
                                 reinterpret_cast<const unsigned char *>(cipherText.constData()),
                                 cipherText.size())
                   != 1) {
            break;
        }
        total = cipherText.isEmpty() ? 0 : length;
        QByteArray tagBuffer = tag;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, kTagSize, tagBuffer.data()) != 1) {
            break;
        }
        if (EVP_DecryptFinal_ex(ctx,
                                reinterpret_cast<unsigned char *>(output.data()) + total,
                                &length)
            != 1) {
            if (error) {
                *error = QStringLiteral("字段完整性校验失败，数据可能被篡改或密钥不匹配");
            }
            break;
        }
        total += length;
        output.truncate(total);
        *plainText = output;
        ok = true;
    } while (false);
    EVP_CIPHER_CTX_free(ctx);
    if (!ok && error && error->isEmpty()) {
        *error = QStringLiteral("AES-GCM 解密失败");
    }
    return ok;
}
#endif

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
#ifdef Q_OS_WIN
    const QByteArray magic(kWindowsMagic, sizeof(kWindowsMagic) - 1);
#else
    const QByteArray magic(kPortableMagic, sizeof(kPortableMagic) - 1);
#endif
    if (data.size() <= magic.size() || data.left(magic.size()) != magic) {
        if (error) {
            *error = QStringLiteral("密钥文件格式无效，或来自其他平台/其他保护方式");
        }
        return false;
    }

    QByteArray key;
    if (!unprotectKey(data.mid(magic.size()), &key, error)) {
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
    const QByteArray key = randomBytes(kKeySize);

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
#ifdef Q_OS_WIN
    file.write(kWindowsMagic, sizeof(kWindowsMagic) - 1);
#else
    file.write(kPortableMagic, sizeof(kPortableMagic) - 1);
#endif
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
#ifdef Q_OS_WIN
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    NTSTATUS status = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_AES_ALGORITHM, nullptr, 0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("无法初始化 AES 加密算法：%1")
                             .arg(windowsError(static_cast<quint32>(status)));
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
            *error = QStringLiteral("无法启用 AES-GCM 模式：%1")
                             .arg(windowsError(static_cast<quint32>(status)));
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
            *error = QStringLiteral("无法创建 AES 密钥句柄：%1")
                             .arg(windowsError(static_cast<quint32>(status)));
        }
        return false;
    }

    m_alg = algorithm;
    m_keyHandle = keyHandle;
    return true;
#else
    if (m_key.size() != kKeySize) {
        if (error) {
            *error = QStringLiteral("密钥长度无效");
        }
        return false;
    }
    return true;
#endif
}

QByteArray Encryption::encrypt(const QByteArray &plaintext, const QByteArray &aad,
                               QString *error) const {
    if (!isReady()) {
        if (error) {
            *error = QStringLiteral("加密服务尚未初始化");
        }
        return {};
    }

    const QByteArray nonce = randomBytes(kNonceSize);
    QByteArray tag(kTagSize, '\0');
    QByteArray cipherText;

#ifdef Q_OS_WIN
    BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo;
    BCRYPT_INIT_AUTH_MODE_INFO(authInfo);
    authInfo.pbNonce = reinterpret_cast<PUCHAR>(const_cast<char *>(nonce.constData()));
    authInfo.cbNonce = static_cast<ULONG>(nonce.size());
    authInfo.pbAuthData = aad.isEmpty()
                              ? nullptr
                              : reinterpret_cast<PUCHAR>(const_cast<char *>(aad.constData()));
    authInfo.cbAuthData = static_cast<ULONG>(aad.size());
    authInfo.pbTag = reinterpret_cast<PUCHAR>(tag.data());
    authInfo.cbTag = static_cast<ULONG>(tag.size());

    BCRYPT_KEY_HANDLE keyHandle = static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle);
    ULONG resultSize = 0;
    NTSTATUS status = BCryptEncrypt(keyHandle,
                                    plaintext.isEmpty()
                                            ? nullptr
                                            : reinterpret_cast<PUCHAR>(const_cast<char *>(plaintext.constData())),
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
            *error = QStringLiteral("加密字段失败：%1")
                             .arg(windowsError(static_cast<quint32>(status)));
        }
        return {};
    }

    cipherText = QByteArray(static_cast<int>(resultSize), '\0');
    status = BCryptEncrypt(keyHandle,
                           plaintext.isEmpty()
                                   ? nullptr
                                   : reinterpret_cast<PUCHAR>(const_cast<char *>(plaintext.constData())),
                           static_cast<ULONG>(plaintext.size()),
                           &authInfo,
                           nullptr,
                           0,
                           resultSize == 0 ? nullptr
                                           : reinterpret_cast<PUCHAR>(cipherText.data()),
                           static_cast<ULONG>(cipherText.size()),
                           &resultSize,
                           0);
    if (!BCRYPT_SUCCESS(status)) {
        if (error) {
            *error = QStringLiteral("加密字段失败：%1")
                             .arg(windowsError(static_cast<quint32>(status)));
        }
        return {};
    }
    cipherText.truncate(static_cast<int>(resultSize));
#else
    if (!opensslEncrypt(m_key, nonce, aad, plaintext, &cipherText, &tag, error)) {
        return {};
    }
#endif

    QByteArray blob;
    blob.reserve(1 + nonce.size() + tag.size() + cipherText.size());
    blob.append(static_cast<char>(kBlobVersion));
    blob.append(nonce);
    blob.append(tag);
    blob.append(cipherText);
    return blob;
}

QByteArray Encryption::decrypt(const QByteArray &blob, const QByteArray &aad,
                               QString *error) const {
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
    QByteArray plainText;

#ifdef Q_OS_WIN
    BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO authInfo;
    BCRYPT_INIT_AUTH_MODE_INFO(authInfo);
    authInfo.pbNonce = reinterpret_cast<PUCHAR>(const_cast<char *>(nonce.constData()));
    authInfo.cbNonce = static_cast<ULONG>(nonce.size());
    authInfo.pbAuthData = aad.isEmpty()
                              ? nullptr
                              : reinterpret_cast<PUCHAR>(const_cast<char *>(aad.constData()));
    authInfo.cbAuthData = static_cast<ULONG>(aad.size());
    authInfo.pbTag = reinterpret_cast<PUCHAR>(const_cast<char *>(tag.constData()));
    authInfo.cbTag = static_cast<ULONG>(tag.size());

    BCRYPT_KEY_HANDLE keyHandle = static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle);
    ULONG resultSize = 0;
    NTSTATUS status = BCryptDecrypt(keyHandle,
                                    cipherText.isEmpty()
                                            ? nullptr
                                            : reinterpret_cast<PUCHAR>(const_cast<char *>(cipherText.constData())),
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

    plainText = QByteArray(static_cast<int>(resultSize), '\0');
    status = BCryptDecrypt(keyHandle,
                           cipherText.isEmpty()
                                   ? nullptr
                                   : reinterpret_cast<PUCHAR>(const_cast<char *>(cipherText.constData())),
                           static_cast<ULONG>(cipherText.size()),
                           &authInfo,
                           nullptr,
                           0,
                           resultSize == 0 ? nullptr
                                           : reinterpret_cast<PUCHAR>(plainText.data()),
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
#else
    if (!opensslDecrypt(m_key, nonce, aad, cipherText, tag, &plainText, error)) {
        return {};
    }
#endif
    return plainText;
}

void Encryption::cleanup() {
#ifdef Q_OS_WIN
    if (m_keyHandle) {
        BCryptDestroyKey(static_cast<BCRYPT_KEY_HANDLE>(m_keyHandle));
        m_keyHandle = nullptr;
    }
    if (m_alg) {
        BCryptCloseAlgorithmProvider(static_cast<BCRYPT_ALG_HANDLE>(m_alg), 0);
        m_alg = nullptr;
    }
#endif
    m_key.clear();
}
