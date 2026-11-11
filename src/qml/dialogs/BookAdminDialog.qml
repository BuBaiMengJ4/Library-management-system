import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 800
    implicitHeight: 720

    property int bookNumber: 0
    property var bookData: ({})
    property var loans: []

    function openFor(number) {
        bookNumber = number
        refresh()
        open()
    }

    function refresh() {
        bookData = LibraryService.findBook(bookNumber)
        loans = LibraryService.bookLoans(bookNumber)
    }

    Connections {
        target: LibraryService
        function onBooksChanged() {
            if (dialog.visible) {
                dialog.refresh()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            FluText {
                Layout.fillWidth: true
                text: I18n.t("图书详情与借阅历史")
                font: FluTextStyle.TitleLarge
                elide: Text.ElideRight
            }
            FluIconButton {
                iconSource: FluentIcons.ChromeClose
                iconSize: 10
                width: 28
                height: 28
                onClicked: dialog.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 110
                Layout.preferredHeight: 140
                radius: 8
                clip: true
                color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)

                Image {
                    id: coverImage
                    anchors.fill: parent
                    source: dialog.bookData && dialog.bookData.hasCover
                            ? "image://library/cover/" + dialog.bookNumber
                              + "?v=" + LibraryService.imageRevision
                            : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: coverImage.status !== Image.Ready
                    spacing: 4
                    FluIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconSource: FluentIcons.Library
                        iconSize: 30
                        iconColor: FluTheme.primaryColor
                    }
                    FluText {
                        text: dialog.bookData ? (dialog.bookData.numberText || "") : ""
                        font: FluTextStyle.BodyStrong
                        textColor: FluTheme.primaryColor
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                FluText {
                    Layout.fillWidth: true
                    text: dialog.bookData ? (dialog.bookData.name || "") : ""
                    font: FluTextStyle.TitleLarge
                    elide: Text.ElideRight
                }
                FluText {
                    Layout.fillWidth: true
                    text: (dialog.bookData ? (dialog.bookData.author || "") : "")
                          + " · " + (dialog.bookData ? (dialog.bookData.publisher || "") : "")
                    font: FluTextStyle.Body
                    textColor: FluTheme.fontSecondaryColor
                    elide: Text.ElideRight
                }
                RowLayout {
                    spacing: 10
                    FluText {
                        text: I18n.t("分类：") + (dialog.bookData ? (dialog.bookData.category || "") : "")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: I18n.t("位置：") + (dialog.bookData ? (dialog.bookData.place || "") : "")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: I18n.t("索书号：") + dialog.bookNumber
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                }
                FluText {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 60
                    text: dialog.bookData ? (dialog.bookData.description || "") : ""
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontTertiaryColor
                    wrapMode: Text.Wrap
                    elide: Text.ElideRight
                }
                FluText {
                    text: dialog.bookData && dialog.bookData.available
                          ? I18n.t("当前状态：在馆")
                          : I18n.t("当前状态：已借出")
                    font: FluTextStyle.Caption
                    textColor: dialog.bookData && dialog.bookData.overdue
                               ? "#D83B3B"
                               : FluTheme.fontSecondaryColor
                }
            }
        }

        FluDivider {
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            FluText {
                Layout.fillWidth: true
                text: I18n.t("借阅历史")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.f("共 {0} 条记录", [dialog.loans.length])
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
            }
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: dialog.loans
            ScrollBar.vertical: FluScrollBar {}

            delegate: Rectangle {
                width: ListView.view.width
                height: 68
                radius: 8
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.03) : Qt.rgba(1, 1, 1, 0.8)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                        FluText {
                            anchors.centerIn: parent
                            text: modelData.displayName.length > 0
                                  ? modelData.displayName.charAt(0).toUpperCase()
                                  : "?"
                            font: FluTextStyle.BodyStrong
                            textColor: FluTheme.primaryColor
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        FluText {
                            text: modelData.displayName + " (" + modelData.username + ")"
                            font: FluTextStyle.BodyStrong
                        }
                        FluText {
                            text: modelData.borrowedAt + "  →  "
                                  + (modelData.returned ? modelData.returnedAt : I18n.t("未归还"))
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 140
                        spacing: 2
                        FluText {
                            text: I18n.f("时长：{0} 天 {1} 小时",
                                         [Math.floor(modelData.durationHours / 24),
                                          modelData.durationHours % 24])
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                        }
                        FluText {
                            text: modelData.returned
                                  ? I18n.t("已归还")
                                  : (modelData.overdue ? I18n.t("已逾期")
                                                       : I18n.t("借阅中"))
                            font: FluTextStyle.Caption
                            textColor: modelData.overdue && !modelData.returned
                                       ? "#D83B3B" : FluTheme.fontSecondaryColor
                        }
                    }

                    FluButton {
                        visible: !modelData.returned
                        text: I18n.t("帮助归还")
                        onClicked: {
                            var error = LibraryService.adminReturnLoan(modelData.id)
                            if (error === "") {
                                var win = Window.window
                                if (win) {
                                    win.showSuccess(I18n.t("已帮助该用户归还"))
                                }
                            } else {
                                var win2 = Window.window
                                if (win2) {
                                    win2.showError(I18n.t(error))
                                }
                            }
                        }
                    }

                    FluTextButton {
                        visible: !modelData.manualUnreturned
                        text: I18n.t("标记未还")
                        onClicked: {
                            var error = LibraryService.adminMarkUnreturned(modelData.id)
                            if (error === "") {
                                var win = Window.window
                                if (win) {
                                    win.showSuccess(I18n.t("已标记为未还"))
                                }
                            } else {
                                var win2 = Window.window
                                if (win2) {
                                    win2.showError(I18n.t(error))
                                }
                            }
                        }
                    }
                }
            }
        }

        FluText {
            Layout.fillWidth: true
            visible: dialog.loans.length === 0
            text: I18n.t("这本书还没有借阅记录。")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontTertiaryColor
            horizontalAlignment: Text.AlignHCenter
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            FluFilledButton {
                Layout.preferredWidth: 100
                text: I18n.t("关闭")
                onClicked: dialog.close()
            }
        }
    }
}
