import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 400
    implicitHeight: contentColumn.implicitHeight + 56

    signal loggedIn()

    property string errorText: ""

    onOpened: {
        errorText = ""
        if (LibraryService.prefillDefaultAdmin) {
            usernameField.text = "Administrator"
            passwordField.text = "114514"
        }
        if (usernameField.text.length === 0) {
            usernameField.forceActiveFocus()
        } else if (passwordField.text.length === 0) {
            passwordField.forceActiveFocus()
        } else {
            loginButton.forceActiveFocus()
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Image {
                source: FluApp.windowIcon
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                fillMode: Image.PreserveAspectFit
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                FluText {
                    text: I18n.t("登录")
                    font: FluTextStyle.TitleLarge
                }
                FluText {
                    text: I18n.t("登录后可以借阅图书、续借和查看借阅额度")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }
        }

        FluTextBox {
            id: usernameField
            Layout.fillWidth: true
            placeholderText: I18n.t("用户名")
            iconSource: FluentIcons.Contact
            onCommit: passwordField.forceActiveFocus()
        }

        FluPasswordBox {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: I18n.t("密码")
            onCommit: dialog.tryLogin()
        }

        FluText {
            Layout.fillWidth: true
            visible: dialog.errorText !== ""
            text: I18n.t(dialog.errorText)
            textColor: "#D83B3B"
            font: FluTextStyle.Caption
            wrapMode: Text.WrapAnywhere
        }

        Rectangle {
            Layout.fillWidth: true
            height: 42
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
                    text: I18n.t("管理员默认账号：Administrator / 114514")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    elide: Text.ElideRight
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 10
            Item {
                Layout.fillWidth: true
            }
            FluTextButton {
                text: I18n.t("取消")
                onClicked: dialog.close()
            }
            FluFilledButton {
                id: loginButton
                Layout.preferredWidth: 120
                text: I18n.t("登录")
                disabled: !LibraryService.storageReady
                          || usernameField.text.length === 0
                          || passwordField.text.length === 0
                onClicked: dialog.tryLogin()
            }
        }

        FluText {
            Layout.fillWidth: true
            visible: !LibraryService.storageReady
            text: I18n.t("加密数据库不可用：") + LibraryService.storageError
            textColor: "#D83B3B"
            font: FluTextStyle.Caption
            wrapMode: Text.WrapAnywhere
        }
    }

    function tryLogin() {
        errorText = ""
        if (usernameField.text.length === 0 || passwordField.text.length === 0) {
            errorText = "请输入用户名和密码"
            return
        }
        if (LibraryService.login(usernameField.text, passwordField.text)) {
            passwordField.text = ""
            loggedIn()
            close()
        } else {
            errorText = LibraryService.lastError
            passwordField.text = ""
            passwordField.forceActiveFocus()
        }
    }
}
