import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"
import "../dialogs"

FluContentPage {
    id: page
    title: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 16

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            visible: LibraryService.isLoggedIn && !LibraryService.isAdmin
            radius: 10
            border.width: 1
            border.color: FluTheme.dividerColor
            color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 20

                Rectangle {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    radius: 32
                    clip: true
                    color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)

                    Image {
                        id: profileAvatar
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: LibraryService.isLoggedIn && LibraryService.currentHasAvatar
                                ? "image://library/avatar/" + LibraryService.currentUsername
                                  + "?v=" + LibraryService.imageRevision
                                : ""
                        visible: status === Image.Ready
                    }

                    FluText {
                        anchors.centerIn: parent
                        visible: profileAvatar.status !== Image.Ready
                        text: LibraryService.currentDisplayName.length > 0
                              ? LibraryService.currentDisplayName.charAt(0).toUpperCase()
                              : "?"
                        font: FluTextStyle.TitleLarge
                        textColor: FluTheme.primaryColor
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    FluText {
                        text: LibraryService.currentDisplayName
                        font: FluTextStyle.TitleLarge
                    }
                    FluText {
                        text: I18n.t("读者账户") + " · "
                              + I18n.f("已借 {0} 本", [LibraryService.myBorrowCount])
                        font: FluTextStyle.Body
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: LibraryService.blacklisted
                              ? I18n.t("有逾期未还图书，已被列入黑名单")
                              : I18n.t("借阅期限 1 个月，每本可续借一次")
                        font: FluTextStyle.Caption
                        textColor: LibraryService.blacklisted
                                     ? "#D83B3B" : FluTheme.fontTertiaryColor
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 330
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        FluText {
                            text: I18n.t("借阅额度")
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        FluText {
                            text: LibraryService.myBorrowCount + " / " + LibraryService.myBorrowLimit
                            font: FluTextStyle.BodyStrong
                        }
                    }
                    FluProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: LibraryService.myBorrowLimit
                        value: LibraryService.myBorrowCount
                        indeterminate: false
                        strokeWidth: 8
                    }
                    FluText {
                        text: I18n.f("剩余 {0} 本可借",
                                     [LibraryService.stats.myRemaining || 0])
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            visible: !LibraryService.isLoggedIn
            radius: 10
            border.width: 1
            border.color: FluTheme.dividerColor
            color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                FluIcon {
                    Layout.alignment: Qt.AlignHCenter
                    iconSource: FluentIcons.Contact
                    iconSize: 28
                    iconColor: FluTheme.primaryColor
                }
                FluText {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("登录后查看借阅数量和剩余额度")
                    font: FluTextStyle.BodyStrong
                }
                FluFilledButton {
                    Layout.alignment: Qt.AlignHCenter
                    text: I18n.t("登录")
                    onClicked: page.openLogin()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            visible: LibraryService.isAdmin
            radius: 8
            color: Qt.rgba(196 / 255, 106 / 255, 27 / 255, 0.10)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                FluIcon {
                    iconSource: FluentIcons.Admin
                    iconSize: 16
                    iconColor: "#C46A1B"
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("管理员账号不能借阅图书。请到管理中心查看用户借阅记录、帮助归还或标记未还。")
                    font: FluTextStyle.Caption
                    textColor: "#C46A1B"
                    elide: Text.ElideRight
                }
                FluTextButton {
                    text: I18n.t("前往管理中心")
                    onClicked: page.navigateTo("admin")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            FluText {
                text: I18n.t("在借清单")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.f("共 {0} 本", [LibraryService.myBorrowedBooks.length])
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }
            Item {
                Layout.fillWidth: true
            }
            FluText {
                visible: LibraryService.isLoggedIn && !LibraryService.isAdmin
                text: I18n.t("到期前可以续借一次，逾期将进入黑名单")
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
                visible: LibraryService.isLoggedIn
                         && !LibraryService.isAdmin
                         && LibraryService.myBorrowedBooks.length > 0
                clip: true
                spacing: 10
                model: LibraryService.myBorrowedBooks
                ScrollBar.vertical: FluScrollBar {}

                delegate: BookCard {
                    width: ListView.view.width
                    book: modelData
                    showReturn: true
                    showRenew: true
                    onReturnRequested: page.doReturn(book)
                    onRenewRequested: page.doRenew(book)
                    onDetailRequested: bookDetail.openFor(book.number)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: LibraryService.isLoggedIn
                         && !LibraryService.isAdmin
                         && LibraryService.myBorrowedBooks.length === 0
                iconSource: FluentIcons.Bookmarks
                title: I18n.t("还没有借阅记录")
                description: I18n.t("借阅的图书会显示在这里，并记录借阅时间、应还日期和续借状态。")
            }
        }
    }

    BookDetailDialog {
        id: bookDetail
    }

    function openLogin() {
        var win = Window.window
        if (win) {
            win.openLogin()
        }
    }

    function navigateTo(route) {
        var win = Window.window
        if (win && win.goToPage) {
            win.goToPage(route)
        }
    }

    function doReturn(book) {
        var error = LibraryService.returnBook(book.number)
        if (error === "") {
            toast(I18n.f("归还成功：《{0}》", [book.name]), true)
        } else {
            toast(error, false)
        }
    }

    function doRenew(book) {
        var error = LibraryService.renewBook(book.number)
        if (error === "") {
            toast(I18n.f("续借成功：《{0}》", [book.name]), true)
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
            win.showError(I18n.t(message))
        }
    }
}
