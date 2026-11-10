import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluWindow {
    id: window
    property int preferredHeight: Math.min(720, Screen.desktopAvailableHeight - 80)
    width: 560
    height: preferredHeight
    minimumWidth: 560
    minimumHeight: preferredHeight
    maximumWidth: 560
    maximumHeight: preferredHeight
    fixSize: true
    showMaximize: false
    showDark: true
    title: "图书管理系统 · 登录"

    property string errorMessage: ""

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: FluTheme.dark ? Qt.rgba(0.07, 0.09, 0.14, 1) : Qt.rgba(0.94, 0.97, 1.0, 1)
            }
            GradientStop {
                position: 1.0
                color: FluTheme.dark ? Qt.rgba(0.03, 0.04, 0.07, 1) : Qt.rgba(0.87, 0.92, 0.98, 1)
            }
        }

        Rectangle {
            width: 340
            height: 340
            radius: 170
            x: -130
            y: -110
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)
        }

        Rectangle {
            width: 260
            height: 260
            radius: 130
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -90
            anchors.bottomMargin: -70
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.08)
        }
    }

    FluFrame {
        id: card
        anchors.centerIn: parent
        width: 420
        implicitHeight: form.implicitHeight + 64
        radius: 12
        border.width: 1
        border.color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
        color: FluTheme.dark ? Qt.rgba(31 / 255, 31 / 255, 31 / 255, 0.94) : Qt.rgba(1, 1, 1, 0.94)

        ColumnLayout {
            id: form
            anchors.fill: parent
            anchors.margins: 32
            spacing: 12

            Image {
                source: "qrc:/resources/library.ico"
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                Layout.alignment: Qt.AlignHCenter
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            FluText {
                text: "图书管理系统"
                font: FluTextStyle.TitleLarge
                Layout.alignment: Qt.AlignHCenter
            }

            FluText {
                text: "LIBRARY MANAGEMENT SYSTEM · VISION 1.0"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
            }

            Item {
                Layout.preferredHeight: 8
            }

            FluTextBox {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: "用户名"
                iconSource: FluentIcons.Contact
                onCommit: passwordField.forceActiveFocus()
                Component.onCompleted: forceActiveFocus()
            }

            FluPasswordBox {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "密码"
                onCommit: window.attemptLogin()
            }

            FluText {
                visible: window.errorMessage !== ""
                text: window.errorMessage
                textColor: "#D83B3B"
                font: FluTextStyle.Caption
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: storageErrorText.implicitHeight + 16
                visible: !LibraryService.storageReady
                radius: 6
                color: Qt.rgba(196 / 255, 43 / 255, 28 / 255, 0.10)

                FluText {
                    id: storageErrorText
                    x: 8
                    y: 8
                    width: parent.width - 16
                    text: "加密数据库不可用：" + LibraryService.storageError
                    textColor: "#D83B3B"
                    font: FluTextStyle.Caption
                    wrapMode: Text.WrapAnywhere
                }
            }

            FluFilledButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: "登 录"
                disabled: !LibraryService.storageReady
                          || usernameField.text.length === 0
                          || passwordField.text.length === 0
                onClicked: window.attemptLogin()
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                height: 44
                radius: 6
                color: FluTools.withOpacity(FluTheme.primaryColor, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    FluIcon {
                        iconSource: FluentIcons.Info
                        iconSize: 14
                        iconColor: FluTheme.primaryColor
                    }
                    FluText {
                        Layout.fillWidth: true
                        text: "管理员默认账号：Administrator / 114514"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        elide: Text.ElideRight
                    }
                }
            }

            FluText {
                text: "读者账号请联系管理员创建 · 数据保存在本地"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
            }
        }
    }

    function attemptLogin() {
        if (!LibraryService.storageReady) {
            errorMessage = "加密数据库不可用：" + LibraryService.storageError
            return
        }
        if (usernameField.text.length === 0 || passwordField.text.length === 0) {
            errorMessage = "请输入用户名和密码"
            return
        }
        errorMessage = ""
        if (LibraryService.login(usernameField.text, passwordField.text)) {
            FluRouter.navigate("/main")
            window.close()
        } else {
            errorMessage = LibraryService.lastError
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
}
