import QtQuick
import QtQuick.Layouts
import FluentUI 1.0
import Library 1.0

FluFrame {
    id: control
    property var book: ({})
    property bool showBorrow: false
    property bool showReturn: false
    property bool showRenew: false
    property bool adminMode: false
    property bool showBorrower: false

    signal borrowRequested()
    signal returnRequested()
    signal renewRequested()
    signal manageRequested()
    signal detailRequested()

    implicitHeight: 112
    height: implicitHeight
    radius: 8
    border.width: 1
    border.color: FluTheme.dividerColor
    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.detailRequested()
    }

    RowLayout {
        anchors.fill: parent
        z: 1
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 82
            radius: 6
            clip: true
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)

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
                spacing: 2
                FluIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconSource: FluentIcons.Library
                    iconSize: 20
                    iconColor: FluTheme.primaryColor
                }
                FluText {
                    text: control.book ? (control.book.numberText || "") : ""
                    font: FluTextStyle.Caption
                    textColor: FluTheme.primaryColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                FluText {
                    text: control.book ? (control.book.name || "") : ""
                    font: FluTextStyle.BodyStrong
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Rectangle {
                    visible: control.book
                             && (control.book.category || "") !== ""
                             && (control.book.category || "") !== "未分类"
                    height: 20
                    width: categoryText.implicitWidth + 12
                    radius: 3
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)
                    FluText {
                        id: categoryText
                        anchors.centerIn: parent
                        text: control.book ? (control.book.category || "") : ""
                        font: FluTextStyle.Caption
                        textColor: FluTheme.primaryColor
                    }
                }
            }

            FluText {
                Layout.fillWidth: true
                text: (control.book ? (control.book.author || "") : "")
                      + " · " + (control.book ? (control.book.publisher || "") : "")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                elide: Text.ElideRight
            }

            FluText {
                Layout.fillWidth: true
                visible: control.book && (control.book.description || "") !== ""
                text: control.book ? (control.book.description || "") : ""
                textFormat: Text.MarkdownText
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            RowLayout {
                spacing: 10
                FluText {
                    text: I18n.t("位置：") + (control.book ? (control.book.place || "") : "")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    elide: Text.ElideRight
                }
                FluText {
                    visible: control.showBorrower && (control.book.borrower || "") !== ""
                    text: I18n.t("借阅人：") + (control.book.borrowerDisplayName || "")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    elide: Text.ElideRight
                }
                FluText {
                    visible: (control.book.isMine === true)
                             && (control.book.dueDate || "") !== ""
                    text: I18n.f("应还 {0}", [control.book.dueDate || ""])
                    font: FluTextStyle.Caption
                    textColor: control.book.overdue ? "#D83B3B" : FluTheme.fontTertiaryColor
                }
            }
        }

        ColumnLayout {
            spacing: 6
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: pillText.implicitWidth + 16
                Layout.preferredHeight: 22
                radius: 4
                color: {
                    if (control.book.isMine) {
                        return FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                    }
                    if (control.book.available) {
                        return Qt.rgba(16 / 255, 124 / 255, 16 / 255, 0.12)
                    }
                    if (control.book.overdue) {
                        return Qt.rgba(196 / 255, 43 / 255, 28 / 255, 0.14)
                    }
                    return Qt.rgba(196 / 255, 106 / 255, 27 / 255, 0.12)
                }
                FluText {
                    id: pillText
                    anchors.centerIn: parent
                    font: FluTextStyle.Caption
                    text: {
                        if (control.book.isMine) {
                            return control.book.overdue ? I18n.t("已逾期") : I18n.t("我的借阅")
                        }
                        if (control.book.available) {
                            return I18n.t("在馆")
                        }
                        return control.book.overdue ? I18n.t("已逾期") : I18n.t("借出")
                    }
                    textColor: {
                        if (control.book.isMine) {
                            return control.book.overdue ? "#D83B3B" : FluTheme.primaryColor
                        }
                        if (control.book.available) {
                            return Qt.rgba(16 / 255, 124 / 255, 16 / 255, 1)
                        }
                        return control.book.overdue
                               ? "#D83B3B" : Qt.rgba(196 / 255, 106 / 255, 27 / 255, 1)
                    }
                }
            }

            FluFilledButton {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 28
                visible: control.showBorrow && control.book.available === true
                text: I18n.t("借书")
                onClicked: control.borrowRequested()
            }

            FluButton {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 28
                visible: control.showReturn && control.book.isMine === true
                text: I18n.t("归还")
                onClicked: control.returnRequested()
            }

            FluTextButton {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 26
                visible: control.showRenew && control.book.canRenew === true
                text: I18n.t("续借")
                onClicked: control.renewRequested()
            }

            FluButton {
                Layout.preferredWidth: 78
                Layout.preferredHeight: 28
                visible: control.adminMode
                text: I18n.t("管理")
                onClicked: control.manageRequested()
            }
        }
    }
}
