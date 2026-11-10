import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../../components"

ColumnLayout {
    id: tab
    spacing: 12

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 168
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            FluText {
                text: "创建读者账户"
                font: FluTextStyle.Title
            }
            FluText {
                text: "新账户没有管理员权限。密码会保存在本地数据文件中，请勿使用重要密码。"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                FluTextBox {
                    id: usernameField
                    Layout.fillWidth: true
                    placeholderText: "用户名（1-20 个字符）"
                    iconSource: FluentIcons.Contact
                    onCommit: tab.addUser()
                }
                FluTextBox {
                    id: passwordField
                    Layout.preferredWidth: 260
                    placeholderText: "初始密码（4-32 个字符）"
                    echoMode: TextInput.Password
                    cleanEnabled: false
                    onCommit: tab.addUser()
                }
                FluFilledButton {
                    Layout.preferredWidth: 100
                    text: "创建账户"
                    onClicked: tab.addUser()
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        FluText {
            text: "账户列表"
            font: FluTextStyle.Title
        }
        FluText {
            text: "共 " + LibraryService.users.length + " 个"
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
        }

        Item {
            Layout.fillWidth: true
        }

        FluText {
            text: "管理员账户不可删除，也不能删除仍有借阅的账户"
            font: FluTextStyle.Caption
            textColor: FluTheme.fontTertiaryColor
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            id: userList
            anchors.fill: parent
            clip: true
            spacing: 8
            model: LibraryService.users
            ScrollBar.vertical: FluScrollBar {}

            delegate: FluFrame {
                width: ListView.view.width
                height: 68
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        radius: 19
                        color: modelData.admin
                               ? FluTools.withOpacity(FluTheme.primaryColor, 0.16)
                               : (FluTheme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06))
                        FluText {
                            anchors.centerIn: parent
                            text: modelData.username.length > 0
                                  ? modelData.username.charAt(0).toUpperCase()
                                  : "?"
                            font: FluTextStyle.BodyStrong
                            textColor: modelData.admin ? FluTheme.primaryColor : FluTheme.fontPrimaryColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            spacing: 6
                            FluText {
                                text: modelData.username
                                font: FluTextStyle.BodyStrong
                            }
                            Rectangle {
                                visible: modelData.isCurrent
                                width: 42
                                height: 18
                                radius: 3
                                color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                                FluText {
                                    anchors.centerIn: parent
                                    text: "当前"
                                    font: FluTextStyle.Caption
                                    textColor: FluTheme.primaryColor
                                }
                            }
                        }
                        FluText {
                            text: modelData.role + " · 已借 " + modelData.borrowCount + " 本"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 180
                        spacing: 1
                        FluText {
                            text: "密码"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontTertiaryColor
                        }
                        FluText {
                            text: modelData.password
                            font: FluTextStyle.Body
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    FluIconButton {
                        iconSource: FluentIcons.Lock
                        iconSize: 14
                        contentDescription: "重置密码"
                        onClicked: tab.openReset(modelData.username)
                    }

                    FluIconButton {
                        iconSource: FluentIcons.Delete
                        iconSize: 14
                        contentDescription: "删除账户"
                        disabled: modelData.admin || modelData.isCurrent
                        onClicked: tab.confirmRemove(modelData.username)
                    }
                }
            }
        }
    }

    FluContentDialog {
        id: resetDialog
        property string targetUser: ""
        property string newPassword: ""

        title: "重置密码"
        message: "为账号“" + targetUser + "”设置新密码（4-32 个字符）。"
        positiveText: "保存"
        negativeText: "取消"

        contentDelegate: Component {
            FluTextBox {
                width: 320
                placeholderText: "输入新密码"
                echoMode: TextInput.Password
                cleanEnabled: false
                onTextChanged: resetDialog.newPassword = text
            }
        }

        onPositiveClickListener: function() {
            var error = LibraryService.resetPassword(resetDialog.targetUser, resetDialog.newPassword)
            if (error === "") {
                tab.toast("账号“" + resetDialog.targetUser + "”的密码已重置", true)
                resetDialog.close()
            } else {
                tab.toast(error, false)
            }
        }
    }

    FluContentDialog {
        id: removeDialog
        property string targetUser: ""

        title: "删除账户"
        message: "确定要删除账号“" + targetUser + "”吗？此操作不可撤销。"
        positiveText: "删除"
        negativeText: "取消"

        onPositiveClicked: {
            var error = LibraryService.removeUser(removeDialog.targetUser)
            if (error === "") {
                tab.toast("账号“" + removeDialog.targetUser + "”已删除", true)
            } else {
                tab.toast(error, false)
            }
        }
    }

    function addUser() {
        var error = LibraryService.addUser(usernameField.text, passwordField.text)
        if (error === "") {
            toast("账户“" + usernameField.text.trim() + "”创建成功", true)
            usernameField.text = ""
            passwordField.text = ""
            usernameField.forceActiveFocus()
        } else {
            toast(error, false)
        }
    }

    function openReset(username) {
        resetDialog.targetUser = username
        resetDialog.newPassword = ""
        resetDialog.open()
    }

    function confirmRemove(username) {
        removeDialog.targetUser = username
        removeDialog.open()
    }

    function toast(message, success) {
        var win = Window.window
        if (!win) {
            return
        }
        if (success) {
            win.showSuccess(message)
        } else {
            win.showError(message)
        }
    }
}
