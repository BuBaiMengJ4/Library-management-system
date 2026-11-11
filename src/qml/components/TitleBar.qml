import QtQuick
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

    height: 36
    icon: ""
    titleVisible: false
    showDark: true
    showStayTop: false

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        FluIconButton {
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
                onClicked: bar.profileRequested()
            }
        }
    }
}
