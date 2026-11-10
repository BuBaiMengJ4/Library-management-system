import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "图书检索"

    property var results: []

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 14

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            radius: 8
            border.width: 1
            border.color: FluTheme.dividerColor
            color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                FluTextBox {
                    id: keywordField
                    Layout.fillWidth: true
                    placeholderText: "输入书名、作者、出版社或索书号"
                    iconSource: FluentIcons.Search
                    onCommit: page.doSearch()
                }

                FluComboBox {
                    id: modeBox
                    Layout.preferredWidth: 120
                    model: ["全部", "书名", "作者", "索书号"]
                    currentIndex: 0
                    onActivated: page.doSearch()
                }

                FluFilledButton {
                    Layout.preferredWidth: 88
                    text: "搜索"
                    onClicked: page.doSearch()
                }

                FluTextButton {
                    text: "重置"
                    onClicked: {
                        keywordField.text = ""
                        modeBox.currentIndex = 0
                        page.doSearch()
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: "检索结果"
                font: FluTextStyle.Title
            }
            FluText {
                text: "共 " + page.results.length + " 本"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item {
                Layout.fillWidth: true
            }

            FluText {
                text: "提示：可直接在结果中借阅或归还"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: resultList
                anchors.fill: parent
                visible: page.results.length > 0
                clip: true
                spacing: 10
                model: page.results
                ScrollBar.vertical: FluScrollBar {}

                delegate: BookCard {
                    width: ListView.view.width
                    book: modelData
                    showBorrow: true
                    showReturn: true
                    onBorrowRequested: page.doBorrow(book)
                    onReturnRequested: page.doReturn(book)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: page.results.length === 0
                iconSource: keywordField.text.length > 0 ? FluentIcons.Search : FluentIcons.Library
                title: keywordField.text.length > 0 ? "没有找到匹配的图书" : "馆藏中还没有图书"
                description: keywordField.text.length > 0
                             ? "换一个关键词试试，或联系管理员补充馆藏。"
                             : "管理员可以在“管理中心”中录入图书，或载入示例数据。"
            }
        }
    }

    Component.onCompleted: doSearch()

    Connections {
        target: LibraryService
        function onBooksChanged() {
            page.doSearch()
        }
    }

    function doSearch() {
        results = LibraryService.searchBooks(keywordField.text, modeBox.currentIndex)
    }

    function doBorrow(book) {
        var error = LibraryService.borrowBook(book.number)
        if (error === "") {
            toast("借阅成功：《" + book.name + "》", true)
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
