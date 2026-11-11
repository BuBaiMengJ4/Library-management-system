import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 500
    implicitHeight: contentColumn.implicitHeight + 56

    property string avatarPath: ""
    property bool clearAvatar: false
    property string previewSource: ""
    property string errorText: ""

    signal passwordChangeRequested()
    signal logoutRequested()

    onOpened: {
        usernameField.text = LibraryService.currentUsername
        displayNameField.text = LibraryService.currentDisplayName
        avatarPath = ""
        clearAvatar = false
        previewSource = LibraryService.isLoggedIn && LibraryService.currentHasAvatar
                        ? "image://library/avatar/" + LibraryService.currentUsername
                          + "?v=" + LibraryService.imageRevision
                        : ""
        errorText = ""
        displayNameField.forceActiveFocus()
    }

    FileDialog {
        id: avatarDialog
        title: I18n.t("选择头像")
        nameFilters: [I18n.t("图片文件 (*.png *.jpg *.jpeg *.bmp *.webp)")]
        onAccepted: {
            dialog.avatarPath = FluTools.toLocalPath(selectedFile)
            dialog.clearAvatar = false
            dialog.previewSource = selectedFile
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
            spacing: 16

            Rectangle {
                width: 76
                height: 76
                radius: 38
                clip: true
                color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)

                Image {
                    id: avatarPreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: dialog.previewSource
                    visible: status === Image.Ready
                }

                FluText {
                    anchors.centerIn: parent
                    visible: avatarPreview.status !== Image.Ready
                    text: LibraryService.currentDisplayName.length > 0
                          ? LibraryService.currentDisplayName.charAt(0).toUpperCase()
                          : "?"
                    font: FluTextStyle.TitleLarge
                    textColor: FluTheme.primaryColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                FluText {
                    text: I18n.t("个人资料")
                    font: FluTextStyle.TitleLarge
                }
                FluText {
                    text: I18n.t("修改账号名称、显示名称和头像")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
                RowLayout {
                    spacing: 8
                    FluButton {
                        text: I18n.t("选择头像")
                        onClicked: avatarDialog.open()
                    }
                    FluTextButton {
                        text: I18n.t("清除头像")
                        visible: dialog.previewSource !== "" && !dialog.clearAvatar
                        onClicked: {
                            dialog.clearAvatar = true
                            dialog.avatarPath = ""
                            dialog.previewSource = ""
                        }
                    }
                }
            }
        }

        FluText {
            text: I18n.t("账号名称")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
        }
        FluTextBox {
            id: usernameField
            Layout.fillWidth: true
            placeholderText: I18n.t("账号名称")
            iconSource: FluentIcons.Contact
            onCommit: dialog.save()
        }

        FluText {
            text: I18n.t("显示名称")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
        }
        FluTextBox {
            id: displayNameField
            Layout.fillWidth: true
            placeholderText: I18n.t("显示名称")
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

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 8

            FluTextButton {
                text: I18n.t("修改密码")
                onClicked: {
                    dialog.close()
                    dialog.passwordChangeRequested()
                }
            }
            FluTextButton {
                text: I18n.t("退出登录")
                onClicked: {
                    dialog.close()
                    dialog.logoutRequested()
                }
            }
            Item {
                Layout.fillWidth: true
            }
            FluTextButton {
                text: I18n.t("取消")
                onClicked: dialog.close()
            }
            FluFilledButton {
                Layout.preferredWidth: 110
                text: I18n.t("保存")
                onClicked: dialog.save()
            }
        }
    }

    function save() {
        errorText = ""
        var error = LibraryService.updateProfile(displayNameField.text,
                                                 usernameField.text,
                                                 avatarPath, clearAvatar)
        if (error === "") {
            close()
        } else {
            errorText = error
        }
    }
}
