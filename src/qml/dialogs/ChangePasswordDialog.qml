import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 470
    implicitHeight: contentColumn.implicitHeight + 56
    property bool forced: false
    property string errorText: ""

    signal changed()

    closePolicy: forced ? Popup.NoAutoClose : Popup.CloseOnEscape

    onOpened: {
        newPassword.text = ""
        confirmPassword.text = ""
        errorText = ""
        newPassword.forceActiveFocus()
    }

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 24
        spacing: 12

        FluText {
            Layout.fillWidth: true
            text: dialog.forced ? I18n.t("首次登录必须修改密码")
                                : I18n.t("修改密码")
            font: FluTextStyle.TitleLarge
        }

        FluText {
            Layout.fillWidth: true
            text: dialog.forced
                  ? I18n.t("管理员首次登录需要立即设置新密码，完成前不能使用系统。")
                  : I18n.t("新密码必须包含大写字母、小写字母、数字和特殊符号，至少 8 位。")
            font: FluTextStyle.Caption
            textColor: dialog.forced ? "#C46A1B" : FluTheme.fontSecondaryColor
            wrapMode: Text.Wrap
        }

        FluPasswordBox {
            id: newPassword
            Layout.fillWidth: true
            placeholderText: I18n.t("新密码")
        }

        FluPasswordBox {
            id: confirmPassword
            Layout.fillWidth: true
            placeholderText: I18n.t("再次输入新密码")
            onCommit: dialog.save()
        }

        FluText {
            Layout.fillWidth: true
            visible: dialog.errorText !== ""
            text: I18n.t(dialog.errorText)
            textColor: "#D83B3B"
            font: FluTextStyle.Caption
            wrapMode: Text.WrapAnywhere
        }

        FluText {
            Layout.fillWidth: true
            text: I18n.t("要求：至少 8 位，包含大写字母、小写字母、数字和特殊符号（如 !@#$%）。")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontTertiaryColor
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 10
            Item {
                Layout.fillWidth: true
            }
            FluTextButton {
                visible: !dialog.forced
                text: I18n.t("取消")
                onClicked: dialog.close()
            }
            FluFilledButton {
                Layout.preferredWidth: 130
                text: I18n.t("保存新密码")
                onClicked: dialog.save()
            }
        }
    }

    function save() {
        errorText = ""
        if (newPassword.text.length === 0 || confirmPassword.text.length === 0) {
            errorText = "请输入并确认新密码"
            return
        }
        if (newPassword.text !== confirmPassword.text) {
            errorText = "两次输入的密码不一致"
            return
        }
        var error = LibraryService.changeOwnPassword(newPassword.text)
        if (error === "") {
            changed()
            close()
        } else {
            errorText = error
        }
    }
}
