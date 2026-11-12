import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Dialogs
import FluentUI 1.0
import Library 1.0
import "../../components"
import "../../dialogs"

ColumnLayout {
    id: tab
    spacing: 12

    property string coverPath: ""
    property string coverPreviewSource: ""

    FileDialog {
        id: coverDialog
        title: I18n.t("选择图书封面")
        nameFilters: [I18n.t("图片文件 (*.png *.jpg *.jpeg *.bmp *.webp)")]
        onAccepted: {
            tab.coverPath = FluTools.toLocalPath(selectedFile)
            tab.coverPreviewSource = selectedFile
        }
    }

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 336
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 7

            FluText {
                text: I18n.t("录入新图书")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.t("索书号由系统自动分配。封面、简介和分类可以留空。")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 3
                columns: 4
                columnSpacing: 10
                rowSpacing: 8

                FluTextBox {
                    id: nameField
                    Layout.fillWidth: true
                    placeholderText: I18n.t("书名 *")
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: authorField
                    Layout.fillWidth: true
                    placeholderText: I18n.t("作者")
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: publisherField
                    Layout.fillWidth: true
                    placeholderText: I18n.t("出版社")
                    onCommit: tab.addBook()
                }
                FluTextBox {
                    id: placeField
                    Layout.fillWidth: true
                    placeholderText: I18n.t("馆藏位置")
                    onCommit: tab.addBook()
                }
            }

            FluMultilineTextBox {
                id: descriptionField
                Layout.fillWidth: true
                Layout.preferredHeight: 62
                placeholderText: I18n.t("图书简介（可选）")
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FluTextBox {
                    id: categoryField
                    Layout.preferredWidth: 200
                    placeholderText: I18n.t("分类（可选）")
                    onCommit: tab.addBook()
                }

                ColumnLayout {
                    Layout.preferredWidth: 104
                    spacing: 1
                    FluText {
                        text: I18n.t("复本数量")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluSpinBox {
                        id: copiesField
                        Layout.fillWidth: true
                        from: 1
                        to: 100
                        value: 1
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 54
                    radius: 5
                    clip: true
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)

                    Image {
                        id: coverPreview
                        anchors.fill: parent
                        source: tab.coverPreviewSource
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    FluIcon {
                        anchors.centerIn: parent
                        visible: coverPreview.status !== Image.Ready
                        iconSource: FluentIcons.Photo
                        iconSize: 18
                        iconColor: FluTheme.primaryColor
                    }
                }

                FluButton {
                    text: I18n.t("选择封面")
                    onClicked: coverDialog.open()
                }
                FluTextButton {
                    text: I18n.t("清除")
                    visible: tab.coverPreviewSource !== ""
                    onClicked: {
                        tab.coverPath = ""
                        tab.coverPreviewSource = ""
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                FluText {
                    visible: LibraryService.lastBookNumber > 0
                    text: I18n.f("最近新增索书号：{0}", [LibraryService.lastBookNumber])
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
                FluTextButton {
                    text: I18n.t("清空")
                    onClicked: tab.clearForm()
                }
                FluFilledButton {
                    Layout.preferredWidth: 104
                    text: I18n.t("添加图书")
                    onClicked: tab.addBook()
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        FluText {
            text: I18n.t("全部馆藏")
            font: FluTextStyle.Title
        }
        FluText {
            text: I18n.f("共 {0} 本", [LibraryService.books.length])
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
                adminMode: true
                showBorrower: true
                onManageRequested: bookDialog.openFor(modelData.number)
            }
        }

        EmptyState {
            anchors.centerIn: parent
            visible: LibraryService.books.length === 0
            iconSource: FluentIcons.Library
            title: I18n.t("还没有任何图书")
            description: I18n.t("在上方录入第一本图书，或在“数据与示例”页载入示例图书。")
        }
    }

    BookAdminDialog {
        id: bookDialog
    }

    function addBook() {
        var error = LibraryService.addBook(nameField.text, authorField.text,
                                           publisherField.text, placeField.text,
                                           descriptionField.text, categoryField.text,
                                           coverPath, copiesField.value)
        if (error === "") {
            toast(I18n.f("添加成功，索书号 {0}", [LibraryService.lastBookNumber]), true)
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
        descriptionField.text = ""
        categoryField.text = ""
        coverPath = ""
        coverPreviewSource = ""
        copiesField.value = 1
    }

    function toast(message, success) {
        var win = Window.window
        if (!win) {
            return
        }
        if (success) {
            win.showSuccess(message)
        } else {
            win.showError(I18n.t(message))
        }
    }
}
