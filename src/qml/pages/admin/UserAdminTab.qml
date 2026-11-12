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
        Layout.preferredHeight: 174
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 7

            FluText {
                text: I18n.t("创建读者账户")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.t("新账户使用初始密码登录，密码需包含大写、小写、数字和特殊符号，至少 8 位。")
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
                    placeholderText: I18n.t("用户名（1-20 个字符）")
                    iconSource: FluentIcons.Contact
                    onCommit: tab.addUser()
                }
                FluPasswordBox {
                    id: passwordField
                    Layout.preferredWidth: 280
                    placeholderText: I18n.t("初始密码（至少 8 位）")
                }
                FluFilledButton {
                    Layout.preferredWidth: 100
                    text: I18n.t("创建账户")
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
            text: I18n.t("账户列表")
            font: FluTextStyle.Title
        }
        FluText {
            text: I18n.f("共 {0} 个", [LibraryService.users.length])
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
        }
        Item {
            Layout.fillWidth: true
        }
        FluText {
            text: I18n.t("管理员不能查看用户密码，只能重置")
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
            property var owner: tab
            anchors.fill: parent
            clip: true
            spacing: 8
            model: LibraryService.users
            ScrollBar.vertical: FluScrollBar {}

            delegate: FluFrame {
                width: ListView.view.width
                height: 78
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        clip: true
                        color: modelData.admin
                               ? FluTools.withOpacity(FluTheme.primaryColor, 0.16)
                               : (FluTheme.dark ? Qt.rgba(1, 1, 1, 0.08)
                                                : Qt.rgba(0, 0, 0, 0.06))

                        Image {
                            id: userAvatar
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: modelData.hasAvatar
                                    ? "image://library/avatar/" + modelData.username
                                      + "?v=" + LibraryService.imageRevision
                                    : ""
                            visible: status === Image.Ready
                        }

                        FluText {
                            anchors.centerIn: parent
                            visible: userAvatar.status !== Image.Ready
                            text: modelData.displayName.length > 0
                                  ? modelData.displayName.charAt(0).toUpperCase()
                                  : "?"
                            font: FluTextStyle.BodyStrong
                            textColor: modelData.admin
                                       ? FluTheme.primaryColor : FluTheme.fontPrimaryColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            spacing: 6
                            FluText {
                                text: modelData.displayName
                                font: FluTextStyle.BodyStrong
                            }
                            FluText {
                                text: "(" + modelData.username + ")"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontTertiaryColor
                            }
                            Rectangle {
                                visible: modelData.isCurrent
                                width: 40
                                height: 18
                                radius: 3
                                color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                                FluText {
                                    anchors.centerIn: parent
                                    text: I18n.t("当前")
                                    font: FluTextStyle.Caption
                                    textColor: FluTheme.primaryColor
                                }
                            }
                        }
                        RowLayout {
                            spacing: 8
                            FluText {
                                text: modelData.admin ? I18n.t("管理员") : I18n.t("读者")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: I18n.f("已借 {0} 本 · 上限 {1} 本",
                                             [modelData.borrowCount, modelData.borrowLimit])
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                visible: modelData.blacklisted
                                text: I18n.t("黑名单")
                                font: FluTextStyle.Caption
                                textColor: "#D83B3B"
                            }
                            FluText {
                                visible: modelData.locked || modelData.temporaryLocked
                                text: modelData.locked
                                      ? I18n.t("已锁定")
                                      : I18n.f("临时锁定 {0} 分钟",
                                               [modelData.lockMinutes])
                                font: FluTextStyle.Caption
                                textColor: "#C46A1B"
                            }
                            FluText {
                                visible: modelData.mustChangePassword
                                text: I18n.t("待修改密码")
                                font: FluTextStyle.Caption
                                textColor: "#C46A1B"
                            }
                        }
                    }

                    RowLayout {
                        Layout.preferredWidth: 306
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        FluTextButton {
                            Layout.preferredWidth: 58
                            Layout.alignment: Qt.AlignVCenter
                            text: I18n.t("额度")
                            onClicked: ListView.view.owner.openLimit(modelData.username,
                                                                     modelData.borrowLimit)
                        }

                        FluTextButton {
                            Layout.preferredWidth: 62
                            Layout.alignment: Qt.AlignVCenter
                            text: modelData.locked ? I18n.t("解锁") : I18n.t("锁定")
                            enabled: !modelData.admin && !modelData.isCurrent
                            onClicked: {
                                var error = LibraryService.setUserLocked(modelData.username,
                                                                         !modelData.locked)
                                if (error === "") {
                                    ListView.view.owner.toast(
                                                I18n.t(modelData.locked ? "已解锁账户"
                                                                        : "已锁定账户"),
                                                true)
                                } else {
                                    ListView.view.owner.toast(error, false)
                                }
                            }
                        }
                        FluTextButton {
                            Layout.preferredWidth: 100
                            Layout.alignment: Qt.AlignVCenter
                            text: I18n.t("重置密码")
                            onClicked: ListView.view.owner.openReset(modelData.username)
                        }
                        FluTextButton {
                            Layout.preferredWidth: 62
                            Layout.alignment: Qt.AlignVCenter
                            text: I18n.t("删除")
                            enabled: !modelData.admin && !modelData.isCurrent
                            onClicked: ListView.view.owner.confirmRemove(modelData.username)
                        }
                    }
                }
            }
        }
    }

    FluPopup {
        id: limitDialog
        width: 360
        implicitHeight: limitColumn.implicitHeight + 48
        property string targetUser: ""
        property int limitValue: 12

        contentItem: ColumnLayout {
            id: limitColumn
            spacing: 10

            FluText {
                text: I18n.t("设置借阅上限")
                font: FluTextStyle.Title
            }
            FluText {
                Layout.fillWidth: true
                text: I18n.f("账号“{0}”最多可同时借阅多少本图书？", [limitDialog.targetUser])
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                wrapMode: Text.Wrap
            }
            FluSpinBox {
                id: limitSpin
                Layout.fillWidth: true
                from: 1
                to: 100
                value: limitDialog.limitValue
                onValueChanged: limitDialog.limitValue = value
            }
            RowLayout {
                Layout.fillWidth: true
                Item {
                    Layout.fillWidth: true
                }
                FluTextButton {
                    text: I18n.t("取消")
                    onClicked: limitDialog.close()
                }
                FluFilledButton {
                    text: I18n.t("保存")
                    onClicked: tab.saveLimit()
                }
            }
        }
    }

    FluContentDialog {
        id: resetDialog
        property string targetUser: ""
        property string newPassword: ""

        title: I18n.t("重置密码")
        message: I18n.f("为账号“{0}”设置新密码。用户下次登录时必须修改该密码。",
                        [targetUser])
        positiveText: I18n.t("保存")
        negativeText: I18n.t("取消")

        contentDelegate: Component {
            FluPasswordBox {
                width: 340
                placeholderText: I18n.t("新密码（至少 8 位，含大小写和特殊符号）")
                onTextChanged: resetDialog.newPassword = text
            }
        }

        onPositiveClickListener: function() {
            var error = LibraryService.resetPassword(resetDialog.targetUser,
                                                     resetDialog.newPassword)
            if (error === "") {
                tab.toast(I18n.t("密码已重置，用户下次登录需要修改"), true)
                resetDialog.close()
            } else {
                tab.toast(error, false)
            }
        }
    }

    FluContentDialog {
        id: removeDialog
        property string targetUser: ""

        title: I18n.t("删除账户")
        message: I18n.f("确定要删除账号“{0}”吗？此操作不可撤销。", [targetUser])
        positiveText: I18n.t("删除")
        negativeText: I18n.t("取消")

        onPositiveClicked: {
            var error = LibraryService.removeUser(removeDialog.targetUser)
            if (error === "") {
                tab.toast(I18n.t("账户已删除"), true)
            } else {
                tab.toast(error, false)
            }
        }
    }

    function addUser() {
        var error = LibraryService.addUser(usernameField.text, passwordField.text)
        if (error === "") {
            toast(I18n.t("账户创建成功"), true)
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

    function openLimit(username, limit) {
        limitDialog.targetUser = username
        limitDialog.limitValue = limit
        limitSpin.value = limit
        limitDialog.open()
    }

    function saveLimit() {
        var error = LibraryService.setUserBorrowLimit(limitDialog.targetUser,
                                                      limitDialog.limitValue)
        if (error === "") {
            toast(I18n.t("借阅上限已更新"), true)
            limitDialog.close()
        } else {
            toast(error, false)
        }
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
            win.showError(I18n.t(message))
        }
    }
}
