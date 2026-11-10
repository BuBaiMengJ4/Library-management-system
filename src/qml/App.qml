import QtQuick
import FluentUI 1.0

FluLauncher {
    id: launcher

    Component.onCompleted: {
        FluApp.init(launcher, Qt.locale("zh_CN"))
        FluApp.windowIcon = "qrc:/resources/library.ico"
        FluRouter.routes = {
            "/login": "qrc:/qml/LoginWindow.qml",
            "/main": "qrc:/qml/MainWindow.qml"
        }
        FluRouter.navigate("/login")
    }
}
