import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "借阅图书"


    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 154
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8

                    FluText {
                        text: "按索书号借阅"
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: "索书号从 1000 开始，可在图书检索结果或图书卡片上查看。"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 10

                        FluTextBox {
                            id: numberField
                            Layout.fillWidth: true
                            placeholderText: "输入索书号，例如 1000"
                            iconSource: FluentIcons.Search
                            onCommit: page.borrowByNumber()
                        }

                        FluFilledButton {
                            Layout.preferredWidth: 92
                            text: "借阅"
                            onClicked: page.borrowByNumber()
                        }
                    }
                }
            }

            FluFrame {
                Layout.preferredWidth: 330
                Layout.preferredHeight: 154
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 7

                    FluText {
                        text: "我的借阅额度"
                        font: FluTextStyle.Title
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        FluText {
                            text: String(LibraryService.myBorrowCount)
                            font: FluTextStyle.TitleLarge
                            textColor: FluTheme.primaryColor
                        }
                        FluText {
                            text: "/ " + LibraryService.borrowLimit + " 本"
                            font: FluTextStyle.Body
                            textColor: FluTheme.fontSecondaryColor
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 4
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        FluText {
                            text: "剩余 " + LibraryService.stats.myRemaining + " 本"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 6
                        }
                    }

                    FluProgressBar {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        from: 0
                        to: LibraryService.borrowLimit
                        value: LibraryService.myBorrowCount
                        indeterminate: false
                        strokeWidth: 8
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    FluText {
                        text: "归还图书后，借阅额度会立即释放。"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontTertiaryColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: "可借图书"
                font: FluTextStyle.Title
            }
            FluText {
                text: "共 " + LibraryService.availableBooks.length + " 本"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item {
                Layout.fillWidth: true
            }

            FluText {
                text: "每次借阅都会立即写入本地数据文件"
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
                visible: LibraryService.availableBooks.length > 0
                clip: true
                spacing: 10
                model: LibraryService.availableBooks
                ScrollBar.vertical: FluScrollBar {}

                delegate: BookCard {
                    width: ListView.view.width
                    book: modelData
                    showBorrow: true
                    onBorrowRequested: page.doBorrow(book)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: LibraryService.availableBooks.length === 0
                iconSource: FluentIcons.Completed
                title: "暂时没有可借图书"
                description: "全部馆藏都已借出，或尚未录入图书。请稍后再试。"
            }
        }
    }

    function borrowByNumber() {
        var text = numberField.text.trim()
        if (!/^[0-9]+$/.test(text)) {
            toast("请输入数字索书号，例如 1000", false)
            return
        }
        var number = parseInt(text)
        var error = LibraryService.borrowBook(number)
        if (error === "") {
            toast("借阅成功，索书号 " + number, true)
            numberField.text = ""
        } else {
            toast(error, false)
        }
    }

    function doBorrow(book) {
        var error = LibraryService.borrowBook(book.number)
        if (error === "") {
            toast("借阅成功：《" + book.name + "》", true)
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
