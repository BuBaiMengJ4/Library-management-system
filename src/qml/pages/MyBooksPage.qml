import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "我的借阅"


    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 16

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 156
            radius: 10
            border.width: 1
            border.color: FluTheme.dividerColor
            color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 24

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 16
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                    FluIcon {
                        anchors.centerIn: parent
                        iconSource: FluentIcons.Contact
                        iconSize: 28
                        iconColor: FluTheme.primaryColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    FluText {
                        text: LibraryService.currentUsername
                        font: FluTextStyle.TitleLarge
                    }
                    FluText {
                        text: (LibraryService.isAdmin ? "管理员账户" : "读者账户")
                              + " · 已借 " + LibraryService.myBorrowCount + " 本"
                        font: FluTextStyle.Body
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: "每本图书借阅期限建议为 30 天，请按时归还。"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontTertiaryColor
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 330
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            text: "借阅额度"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        FluText {
                            text: LibraryService.myBorrowCount + " / " + LibraryService.borrowLimit
                            font: FluTextStyle.BodyStrong
                        }
                    }
                    FluProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: LibraryService.borrowLimit
                        value: LibraryService.myBorrowCount
                        indeterminate: false
                        strokeWidth: 8
                    }
                    FluText {
                        text: "剩余 " + LibraryService.stats.myRemaining + " 本可借"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: "在借清单"
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
                text: "借阅日期与应还日期会随记录一起保存"
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
                title: "还没有借阅记录"
                description: "借阅的图书会显示在这里，并记录借阅时间与建议归还日期。"
            }
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
