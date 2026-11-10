import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "归还图书"


    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 16

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            radius: 10
            border.width: 1
            border.color: FluTheme.dividerColor
            color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    radius: 10
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                    FluIcon {
                        anchors.centerIn: parent
                        iconSource: FluentIcons.Completed
                        iconSize: 20
                        iconColor: FluTheme.primaryColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    FluText {
                        text: "输入索书号归还"
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: "只能归还当前账号“" + LibraryService.currentUsername + "”名下借出的图书。"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                FluTextBox {
                    id: numberField
                    Layout.preferredWidth: 260
                    placeholderText: "索书号，例如 1000"
                    iconSource: FluentIcons.Search
                    onCommit: page.returnByNumber()
                }

                FluFilledButton {
                    Layout.preferredWidth: 88
                    text: "归还"
                    onClicked: page.returnByNumber()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: "我的在借图书"
                font: FluTextStyle.Title
            }
            FluText {
                text: "共 " + LibraryService.myBorrowedBooks.length + " 本"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item {
                Layout.fillWidth: true
            }

            FluText {
                text: "归还后图书会重新变为“在馆”状态"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                anchors.fill: parent
                visible: LibraryService.myBorrowedBooks.length > 0
                clip: true
                spacing: 10
                model: LibraryService.myBorrowedBooks
                ScrollBar.vertical: FluScrollBar {}

                delegate: BookCard {
                    width: ListView.view.width
                    book: modelData
                    showReturn: true
                    onReturnRequested: page.doReturn(book)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: LibraryService.myBorrowedBooks.length === 0
                iconSource: FluentIcons.Bookmarks
                title: "当前没有在借图书"
                description: "去“借阅图书”看看馆藏，或到“我的借阅”查看借阅额度。"
            }
        }
    }

    function returnByNumber() {
        var text = numberField.text.trim()
        if (!/^[0-9]+$/.test(text)) {
            toast("请输入数字索书号，例如 1000", false)
            return
        }
        var number = parseInt(text)
        var error = LibraryService.returnBook(number)
        if (error === "") {
            toast("归还成功，索书号 " + number, true)
            numberField.text = ""
        } else {
            toast(error, false)
        }
    }

    function doReturn(book) {
        var error = LibraryService.returnBook(book.number)
        if (error === "") {
            toast("归还成功：《" + book.name + "》", true)
        } else {
            toast(error, false)
        }
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
