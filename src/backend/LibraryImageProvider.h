#pragma once

#include <QQuickImageProvider>

class LibraryService;

/**
 * @brief 从 LibraryService 解密内存中的图书封面 / 用户头像。
 *
 * QML 使用：
 *   image://library/cover/1000?v=3
 *   image://library/avatar/Administrator?v=3
 */
class LibraryImageProvider : public QQuickImageProvider {
public:
    explicit LibraryImageProvider(LibraryService *service);

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    LibraryService *m_service = nullptr;
};
