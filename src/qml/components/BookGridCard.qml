import QtQuick
import QtQuick.Layouts
import FluentUI 1.0
import Library 1.0

FluFrame {
    id: control
    property var book: ({})
    property bool showBorrow: false

    signal borrowRequested()
    signal detailRequested()

    implicitHeight: 292
    radius: 8
    border.width: 1
    border.color: cardHover.hovered ? FluTools.withOpacity(FluTheme.primaryColor, 0.45)
                                    : FluTheme.dividerColor
    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

    MouseArea {
        id: cardHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: control.detailRequested()
    }

    ColumnLayout {
        anchors.fill: parent
        z: 1
        anchors.margins: 10
        spacing: 6

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 168
            radius: 6
            clip: true
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)

            Image {
                id: cover
                anchors.fill: parent
                source: control.book && control.book.hasCover
                        ? "image://library/cover/" + control.book.number
                          + "?v=" + LibraryService.imageRevision
                        : ""
                fillMode: Image.PreserveAspectCrop
                visible: status === Image.Ready
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: cover.status !== Image.Ready
                spacing: 3
                FluIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconSource: FluentIcons.Library
                    iconSize: 28
                    iconColor: FluTheme.primaryColor
                }
                FluText {
                    Layout.alignment: Qt.AlignHCenter
                    text: control.book ? (control.book.numberText || "") : ""
                    font: FluTextStyle.Body
                    textColor: FluTheme.primaryColor
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                width: statusText.implicitWidth + 12
                height: 20
                radius: 3
                color: control.book && control.book.available
                       ? Qt.rgba(16 / 255, 124 / 255, 16 / 255, 0.88)
                       : Qt.rgba(196 / 255, 106 / 255, 27 / 255, 0.90)
                FluText {
                    id: statusText
                    anchors.centerIn: parent
                    text: control.book && control.book.available
                          ? I18n.t("在馆") : I18n.t("借出")
                    font: FluTextStyle.Caption
                    textColor: "white"
                }
            }
        }

        FluText {
            Layout.fillWidth: true
            text: control.book ? (control.book.name || "") : ""
            font: FluTextStyle.BodyStrong
            elide: Text.ElideRight
            maximumLineCount: 1
        }
        FluText {
            Layout.fillWidth: true
            text: (control.book ? (control.book.author || "") : "")
                  + " · " + (control.book ? (control.book.publisher || "") : "")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            FluText {
                Layout.fillWidth: true
                text: control.book ? (control.book.category || "") : ""
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                elide: Text.ElideRight
            }
            FluTextButton {
                Layout.preferredHeight: 24
                text: I18n.t("详情")
                font: FluTextStyle.Caption
                onClicked: control.detailRequested()
            }
        }

        Item {
            Layout.fillHeight: true
        }

        FluFilledButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            visible: control.showBorrow && control.book && control.book.available
            text: I18n.t("借书")
            onClicked: control.borrowRequested()
        }
    }
}
