import QtQuick
import FluentUI 1.0

FluLauncher {
    id: launcher

    Component.onCompleted: {
        FluApp.init(launcher, Qt.locale("zh_CN"))
        FluApp.windowIcon = "qrc:/resources/library.ico"
        FluRouter.routes = {
            "/main": "qrc:/qml/MainWindow.qml"
        }
        FluRouter.navigate("/main")
    }
}
