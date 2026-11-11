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

        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8

                    FluText {
                        text: I18n.t("按索书号借阅")
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: I18n.t("借阅期限为 1 个月，每本图书可以续借一次；逾期未还会被列入黑名单。")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 10

                        FluTextBox {
                            id: numberField
                            Layout.fillWidth: true
                            placeholderText: I18n.t("输入索书号，例如 1000")
                            iconSource: FluentIcons.Search
                            onCommit: page.borrowByNumber()
                        }

                        FluFilledButton {
                            Layout.preferredWidth: 92
                            text: I18n.t("借阅")
                            visible: !LibraryService.isAdmin
                            onClicked: page.borrowByNumber()
                        }
                    }
                }
            }

            FluFrame {
                Layout.preferredWidth: 330
                Layout.preferredHeight: 160
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 7

                    FluText {
                        text: I18n.t("我的借阅额度")
                        font: FluTextStyle.Title
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        FluText {
                            text: LibraryService.isLoggedIn && !LibraryService.isAdmin
                                  ? String(LibraryService.myBorrowCount) : "—"
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
                            text: LibraryService.isLoggedIn && !LibraryService.isAdmin
                                  ? I18n.f("剩余 {0} 本",
                                           [LibraryService.stats.myRemaining || 0])
                                  : (LibraryService.isAdmin
                                     ? I18n.t("管理员不可借阅")
                                     : I18n.t("登录后查看"))
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
                        value: LibraryService.isLoggedIn && !LibraryService.isAdmin
                               ? LibraryService.myBorrowCount : 0
                        indeterminate: false
                        strokeWidth: 8
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    FluTextButton {
                        visible: !LibraryService.isLoggedIn
                        text: I18n.t("登录")
                        onClicked: page.openLogin()
                    }

                    FluText {
                        visible: LibraryService.isLoggedIn
                        text: LibraryService.isAdmin
                              ? I18n.t("管理员账号不能借阅图书")
                              : I18n.t("归还图书后，借阅额度会立即释放。")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontTertiaryColor
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            visible: LibraryService.blacklisted
            radius: 6
            color: Qt.rgba(196 / 255, 43 / 255, 28 / 255, 0.10)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8
                FluIcon {
                    iconSource: FluentIcons.Warning
                    iconSize: 15
                    iconColor: "#D83B3B"
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("你名下有逾期未还图书，已被列入黑名单，暂时不能借阅。")
                    font: FluTextStyle.Caption
                    textColor: "#D83B3B"
                    elide: Text.ElideRight
                }
                FluTextButton {
                    text: I18n.t("去归还")
                    onClicked: page.navigateTo("return")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            FluText {
                text: I18n.t("可借图书")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.f("共 {0} 本", [LibraryService.availableBooks.length])
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item {
                Layout.fillWidth: true
            }

            FluText {
                visible: !LibraryService.isLoggedIn
                text: I18n.t("登录后可以借阅")
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
                    showBorrow: !LibraryService.isAdmin
                    onBorrowRequested: page.doBorrow(book)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: LibraryService.availableBooks.length === 0
                iconSource: FluentIcons.Completed
                title: I18n.t("暂时没有可借图书")
                description: I18n.t("全部馆藏都已借出，或尚未录入图书。请稍后再试。")
            }
        }
    }

    function openLogin() {
        var win = Window.window
        if (win) {
            win.openLogin()
        }
    }

    function ensureLogin() {
        if (LibraryService.isLoggedIn) {
            return true
        }
        openLogin()
        return false
    }

    function borrowByNumber() {
        if (!ensureLogin()) {
            return
        }
        if (LibraryService.isAdmin) {
            toast(I18n.t("管理员不能借书"), false)
            return
        }
        var text = numberField.text.trim()
        if (!/^[0-9]+$/.test(text)) {
            toast(I18n.t("请输入数字索书号，例如 1000"), false)
            return
        }
        var number = parseInt(text)
        var error = LibraryService.borrowBook(number)
        if (error === "") {
            toast(I18n.f("借阅成功，索书号 {0}", [number]), true)
            numberField.text = ""
        } else {
            toast(error, false)
        }
    }

    function doBorrow(book) {
        if (!ensureLogin()) {
            return
        }
        if (LibraryService.isAdmin) {
            toast(I18n.t("管理员不能借书"), false)
            return
        }
        var error = LibraryService.borrowBook(book.number)
        if (error === "") {
            toast(I18n.f("借阅成功：《{0}》", [book.name]), true)
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
