#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QStandardPaths>
#include <QTextStream>
#include <QtQml/qqml.h>

#include <cstdio>

#include "backend/LibraryService.h"

namespace {

QFile g_logFile;

void fileMessageHandler(QtMsgType type, const QMessageLogContext &context, const QString &message) {
    const QString text = qFormatLogMessage(type, context, message);
    if (g_logFile.isOpen()) {
        QTextStream stream(&g_logFile);
        stream << QDateTime::currentDateTime().toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz "))
               << text << '\n';
        stream.flush();
    }
    std::fprintf(stderr, "%s\n", text.toLocal8Bit().constData());
}

bool ensureWritableDir(const QString &path) {
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

void setupLogging() {
    QString logDir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                     + QStringLiteral("/logs");
    if (!ensureWritableDir(logDir)) {
        logDir = QCoreApplication::applicationDirPath() + QStringLiteral("/logs");
    }
    if (!ensureWritableDir(logDir)) {
        logDir = QDir::tempPath() + QStringLiteral("/LibraryManagementSystem-logs");
        QDir().mkpath(logDir);
    }
    g_logFile.setFileName(logDir + QStringLiteral("/app.log"));
    if (g_logFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        qInstallMessageHandler(fileMessageHandler);
    }
}

} // namespace

int main(int argc, char *argv[]) {
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(
            Qt::HighDpiScaleFactorRoundingPolicy::PassThrough);
#endif

    QCoreApplication::setOrganizationName(QStringLiteral("BuBaiMengJ4"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("github.com/BuBaiMengJ4"));
    QCoreApplication::setApplicationName(QStringLiteral("LibraryManagementSystem"));
    QCoreApplication::setApplicationVersion(QStringLiteral("1.0.0"));

    QGuiApplication app(argc, argv);
    setupLogging();
    QGuiApplication::setWindowIcon(QIcon(QStringLiteral(":/resources/library.ico")));

    qInfo() << "LibraryManagementSystem 1.0.0 starting";
    qInfo() << "Qt" << QT_VERSION_STR;

    LibraryService libraryService;
    qmlRegisterSingletonInstance("Library", 1, 0, "LibraryService", &libraryService);

    QQmlApplicationEngine engine;
    // 开发构建：<build>/bin + <build>/qml/FluentUI；发布目录：<app>/qml/FluentUI。
    engine.addImportPath(app.applicationDirPath() + QStringLiteral("/qml"));
    engine.addImportPath(app.applicationDirPath() + QStringLiteral("/../qml"));
    engine.addImportPath(QStringLiteral("qrc:/qml"));

    engine.load(QUrl(QStringLiteral("qrc:/qml/App.qml")));
    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
