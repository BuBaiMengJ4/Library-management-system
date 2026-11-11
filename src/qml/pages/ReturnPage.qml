import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

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
                        text: I18n.t("输入索书号归还")
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: LibraryService.isLoggedIn
                              ? I18n.f("只能归还当前账号“{0}”名下的图书。",
                                       [LibraryService.currentDisplayName])
                              : I18n.t("登录后可以归还自己名下的图书。")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                FluTextBox {
                    id: numberField
                    Layout.preferredWidth: 260
                    placeholderText: I18n.t("索书号，例如 1000")
                    iconSource: FluentIcons.Search
                    onCommit: page.returnByNumber()
                }

                FluFilledButton {
                    Layout.preferredWidth: 88
                    text: I18n.t("归还")
                    visible: !LibraryService.isAdmin
                    onClicked: page.returnByNumber()
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
                    iconSource: FluentIcons.Info
                    iconSize: 16
                    iconColor: "#C46A1B"
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("管理员不能自行借书或还书。请前往“管理中心”查看借阅记录并帮助用户归还。")
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

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            visible: !LibraryService.isLoggedIn
            radius: 8
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.08)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                FluIcon {
                    iconSource: FluentIcons.Contact
                    iconSize: 16
                    iconColor: FluTheme.primaryColor
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("登录后才能查看和归还自己借阅的图书。")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    elide: Text.ElideRight
                }
                FluTextButton {
                    text: I18n.t("登录")
                    onClicked: page.openLogin()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: I18n.t("我的在借图书")
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
                text: I18n.t("归还后图书会重新变为“在馆”状态")
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
                visible: !LibraryService.isAdmin
                         && LibraryService.isLoggedIn
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
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: !LibraryService.isAdmin
                         && LibraryService.isLoggedIn
                         && LibraryService.myBorrowedBooks.length === 0
                iconSource: FluentIcons.Bookmarks
                title: I18n.t("当前没有在借图书")
                description: I18n.t("去“借阅图书”看看馆藏，或到“我的借阅”查看借阅额度。")
            }
        }
    }

    function openLogin() {
        var win = Window.window
        if (win) {
            win.openLogin()
        }
    }

    function returnByNumber() {
        if (!LibraryService.isLoggedIn) {
            openLogin()
            return
        }
        if (LibraryService.isAdmin) {
            toast(I18n.t("管理员不能自行还书，请在管理中心帮助用户归还"), false)
            return
        }
        var text = numberField.text.trim()
        if (!/^[0-9]+$/.test(text)) {
            toast(I18n.t("请输入数字索书号，例如 1000"), false)
            return
        }
        var number = parseInt(text)
        var error = LibraryService.returnBook(number)
        if (error === "") {
            toast(I18n.f("归还成功，索书号 {0}", [number]), true)
            numberField.text = ""
        } else {
            toast(error, false)
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

    function navigateTo(route) {
        var win = Window.window
        if (win && win.goToPage) {
            win.goToPage(route)
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
