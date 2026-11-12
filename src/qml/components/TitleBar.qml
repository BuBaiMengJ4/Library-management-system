import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import FluentUI 1.0
import Library 1.0

FluAppBar {
    id: bar
    property string titleKey: ""
    property bool canGoBack: false

    signal backRequested()
    signal loginRequested()
    signal profileRequested()
    signal languageRequested()
    signal logoutRequested()

    height: 36
    icon: ""
    titleVisible: false
    showDark: true
    showStayTop: false

    Component.onCompleted: {
        var win = Window.window
        if (win && win.setHitTestVisible) {
            win.setHitTestVisible(backButton)
            win.setHitTestVisible(rightControls)
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        FluIconButton {
            id: backButton
            iconSource: FluentIcons.ChromeBack
            iconSize: 12
            width: 26
            height: 26
            verticalPadding: 0
            horizontalPadding: 0
            visible: bar.canGoBack
            contentDescription: I18n.t("返回")
            Accessible.name: I18n.t("返回")
            onClicked: bar.backRequested()
        }

        Image {
            width: 18
            height: 18
            source: FluApp.windowIcon
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
        }

        FluText {
            text: I18n.t("图书管理系统")
            font: FluTextStyle.BodyStrong
            anchors.verticalCenter: parent.verticalCenter
        }

        FluText {
            text: "·"
            visible: bar.titleKey !== ""
            textColor: FluTheme.fontTertiaryColor
            anchors.verticalCenter: parent.verticalCenter
        }

        FluText {
            text: bar.titleKey === "" ? "" : I18n.t(bar.titleKey)
            textColor: FluTheme.fontSecondaryColor
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        id: rightControls
        anchors.right: parent.right
        anchors.rightMargin: 166
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        FluIconButton {
            iconSource: FluentIcons.Globe
            iconSize: 14
            width: 28
            height: 28
            verticalPadding: 0
            horizontalPadding: 0
            contentDescription: I18n.t("语言")
            Accessible.name: I18n.t("语言")
            onClicked: bar.languageRequested()
        }

        FluTextButton {
            visible: !LibraryService.isLoggedIn
            text: I18n.t("登录")
            font: FluTextStyle.Body
            onClicked: bar.loginRequested()
        }

        Rectangle {
            id: userChip
            visible: LibraryService.isLoggedIn
            width: chipRow.implicitWidth + 18
            height: 28
            radius: 14
            color: chipHover.hovered
                   ? FluTools.withOpacity(FluTheme.primaryColor, 0.16)
                   : FluTools.withOpacity(FluTheme.primaryColor, 0.08)

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    clip: true
                    color: FluTheme.primaryColor
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: LibraryService.isLoggedIn && LibraryService.currentHasAvatar
                                ? "image://library/avatar/" + LibraryService.currentUsername
                                  + "?v=" + LibraryService.imageRevision
                                : ""
                        visible: status === Image.Ready
                    }

                    FluText {
                        anchors.centerIn: parent
                        visible: avatarImage.status !== Image.Ready
                        text: LibraryService.currentDisplayName.length > 0
                              ? LibraryService.currentDisplayName.charAt(0).toUpperCase()
                              : "?"
                        textColor: "white"
                        font: FluTextStyle.Caption
                    }
                }

                FluText {
                    text: LibraryService.currentDisplayName
                    font: FluTextStyle.Body
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: chipHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.name: I18n.t("个人资料")
                Accessible.role: Accessible.Button
                onClicked: accountPopup.open()
            }
        }
    }

    FluPopup {
        id: accountPopup
        width: 236
        x: Math.max(8, bar.width - width - 12)
        y: bar.height + 4
        padding: 0
        closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

        background: Rectangle {
            radius: 8
            color: FluTheme.dark ? "#2B2B2B" : "#FFFFFF"
            border.width: 1
            border.color: FluTheme.dividerColor
        }

        contentItem: ColumnLayout {
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 14
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    clip: true
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.14)

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: LibraryService.currentHasAvatar
                                ? "image://library/avatar/" + LibraryService.currentUsername
                                  + "?v=" + LibraryService.imageRevision
                                : ""
                        visible: status === Image.Ready
                    }
                    FluText {
                        anchors.centerIn: parent
                        text: LibraryService.currentDisplayName.length > 0
                              ? LibraryService.currentDisplayName.charAt(0).toUpperCase()
                              : "?"
                        font: FluTextStyle.BodyStrong
                        textColor: FluTheme.primaryColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    FluText {
                        Layout.fillWidth: true
                        text: LibraryService.currentDisplayName
                        font: FluTextStyle.BodyStrong
                        elide: Text.ElideRight
                    }
                    FluText {
                        Layout.fillWidth: true
                        text: LibraryService.isAdmin ? I18n.t("管理员") : I18n.t("读者")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                }
            }

            FluDivider {
                Layout.fillWidth: true
            }

            FluTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: I18n.t("修改个人信息")
                onClicked: {
                    accountPopup.close()
                    bar.profileRequested()
                }
            }
            FluTextButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                text: I18n.t("退出登录")
                onClicked: {
                    accountPopup.close()
                    bar.logoutRequested()
                }
            }
        }
    }
}
