import QtQuick
import QtQuick.Layouts
import FluentUI 1.0

FluFrame {
    id: control
    property var book: ({})
    property bool showBorrow: false
    property bool showReturn: false
    property bool showBorrower: false

    signal borrowRequested()
    signal returnRequested()

    implicitHeight: 92
    height: implicitHeight
    radius: 8
    border.width: 1
    border.color: FluTheme.dividerColor
    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

    property string metaText: {
        if (!book) {
            return ""
        }
        var parts = []
        if (book.author) {
            parts.push(book.author)
        }
        if (book.publisher) {
            parts.push(book.publisher)
        }
        return parts.join(" · ")
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 58
            radius: 8
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
            FluText {
                anchors.centerIn: parent
                text: control.book.numberText || ""
                font: FluTextStyle.BodyStrong
                textColor: FluTheme.primaryColor
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 120
            spacing: 3

            FluText {
                text: control.book.name || ""
                font: FluTextStyle.BodyStrong
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            FluText {
                text: control.metaText
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            RowLayout {
                spacing: 10
                FluText {
                    text: "位置 " + (control.book.place || "未分类")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    elide: Text.ElideRight
                }
                FluText {
                    visible: control.showBorrower && (control.book.borrower || "") !== ""
                    text: "借阅人 " + (control.book.borrower || "")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    elide: Text.ElideRight
                }
                FluText {
                    visible: (control.book.isMine === true)
                             && (control.book.borrowedDate || "") !== ""
                    text: "借于 " + (control.book.borrowedDate || "")
                          + " · 应还 " + (control.book.dueDate || "")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: pillText.implicitWidth + 16
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: {
                if (control.book.isMine) {
                    return FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                }
                if (control.book.available) {
                    return Qt.rgba(16 / 255, 124 / 255, 16 / 255, 0.12)
                }
                return Qt.rgba(196 / 255, 43 / 255, 28 / 255, 0.12)
            }
            FluText {
                id: pillText
                anchors.centerIn: parent
                font: FluTextStyle.Caption
                text: control.book.isMine ? "我的借阅" : (control.book.availableText || "未知")
                textColor: {
                    if (control.book.isMine) {
                        return FluTheme.primaryColor
                    }
                    if (control.book.available) {
                        return Qt.rgba(16 / 255, 124 / 255, 16 / 255, 1)
                    }
                    return Qt.rgba(196 / 255, 43 / 255, 28 / 255, 1)
                }
            }
        }

        FluFilledButton {
            visible: control.showBorrow && control.book.available === true
            Layout.preferredWidth: 74
            Layout.preferredHeight: 30
            text: "借书"
            onClicked: control.borrowRequested()
        }

        FluButton {
            visible: control.showReturn && control.book.isMine === true
            Layout.preferredWidth: 74
            Layout.preferredHeight: 30
            text: "归还"
            onClicked: control.returnRequested()
        }
    }
}
