import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../../components"

ColumnLayout {
    id: tab
    spacing: 12

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 228
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 6

            FluText {
                text: "录入新图书"
                font: FluTextStyle.Title
            }
            FluText {
                text: "索书号由系统自动分配，从 1000 开始递增。带 * 的字段为必填。"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                columns: 2
                columnSpacing: 10
                rowSpacing: 8

                FluTextBox {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: "书名 *"
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: authorField
                    Layout.fillWidth: true
                    placeholderText: "作者（默认“佚名”）"
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: publisherField
                    Layout.fillWidth: true
                    placeholderText: "出版社（默认“未知”）"
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: placeField
                    Layout.fillWidth: true
                    placeholderText: "馆藏位置（默认“未分类”）"
                    onCommit: tab.addBook()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 10

                FluText {
                    visible: LibraryService.lastBookNumber > 0
                    text: "最近新增的索书号：" + LibraryService.lastBookNumber
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    Layout.fillWidth: true
                }
                Item {
                    Layout.fillWidth: true
                }
                FluTextButton {
                    text: "清空"
                    onClicked: tab.clearForm()
                }
                FluFilledButton {
                    Layout.preferredWidth: 100
                    text: "添加图书"
                    onClicked: tab.addBook()
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        FluText {
            text: "全部馆藏"
            font: FluTextStyle.Title
        }
        FluText {
            text: "共 " + LibraryService.books.length + " 本"
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
            anchors.fill: parent
            visible: LibraryService.books.length > 0
            clip: true
            spacing: 8
            model: LibraryService.books
            ScrollBar.vertical: FluScrollBar {}

            delegate: BookCard {
                width: ListView.view.width
                book: modelData
                showBorrower: true
            }
        }

        EmptyState {
            anchors.centerIn: parent
            visible: LibraryService.books.length === 0
            iconSource: FluentIcons.Library
            title: "还没有任何图书"
            description: "在上方录入第一本图书，或在“数据与示例”页载入示例图书。"
        }
    }

    function addBook() {
        var error = LibraryService.addBook(nameField.text, authorField.text,
                                           publisherField.text, placeField.text)
        if (error === "") {
            toast("添加成功，索书号 " + LibraryService.lastBookNumber, true)
            clearForm()
            nameField.forceActiveFocus()
        } else {
            toast(error, false)
        }
    }

    function clearForm() {
        nameField.text = ""
        authorField.text = ""
        publisherField.text = ""
        placeField.text = ""
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
