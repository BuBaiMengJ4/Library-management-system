#include "LibraryImageProvider.h"

#include "LibraryService.h"

#include <QImage>
#include <QString>

LibraryImageProvider::LibraryImageProvider(LibraryService *service)
    : QQuickImageProvider(QQuickImageProvider::Image), m_service(service) {
}

QImage LibraryImageProvider::requestImage(const QString &id, QSize *size,
                                          const QSize &requestedSize) {
    QString key = id;
    const int queryIndex = key.indexOf(QLatin1Char('?'));
    if (queryIndex >= 0) {
        key = key.left(queryIndex);
    }

    QImage image;
    if (key.startsWith(QStringLiteral("cover/"))) {
        bool ok = false;
        const int number = key.mid(6).toInt(&ok);
        if (ok) {
            image = m_service->coverImage(number);
        }
    } else if (key.startsWith(QStringLiteral("avatar/"))) {
        image = m_service->avatarImage(key.mid(7));
    }

    if (image.isNull()) {
        if (size) {
            *size = QSize();
        }
        return image;
    }

    if (requestedSize.isValid() && !requestedSize.isEmpty()) {
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    if (size) {
        *size = image.size();
    }
    return image;
}
