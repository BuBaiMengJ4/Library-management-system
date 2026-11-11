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
                    placeholderText: I18n.t("输入书名、作者、分类、出版社或索书号")
                    iconSource: FluentIcons.Search
                    onCommit: page.doSearch()
                }

                FluComboBox {
                    id: modeBox
                    Layout.preferredWidth: 120
                    model: [
                        I18n.t("全部"),
                        I18n.t("书名"),
                        I18n.t("作者"),
                        I18n.t("索书号"),
                        I18n.t("分类")
                    ]
                    currentIndex: 0
                    onActivated: page.doSearch()
                }

                FluFilledButton {
                    Layout.preferredWidth: 88
                    text: I18n.t("搜索")
                    onClicked: page.doSearch()
                }

                FluTextButton {
                    text: I18n.t("重置")
                    onClicked: {
                        keywordField.text = ""
                        modeBox.currentIndex = 0
                        page.doSearch()
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
                    text: I18n.t("你有逾期未还图书，已被列入黑名单，暂时无法借阅。")
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
                text: I18n.t("检索结果")
                font: FluTextStyle.Title
            }
            FluText {
                text: I18n.f("共 {0} 本", [page.results.length])
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: 6
            }

            Item {
                Layout.fillWidth: true
            }

            FluText {
                visible: !LibraryService.isAdmin
                text: LibraryService.isLoggedIn
                      ? I18n.t("提示：可直接在结果中借阅或归还")
                      : I18n.t("提示：借阅和归还前需要先登录")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignVCenter
            }
            FluText {
                visible: LibraryService.isAdmin
                text: I18n.t("管理员不能借阅或归还图书")
                font: FluTextStyle.Caption
                textColor: "#C46A1B"
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
                    showBorrow: !LibraryService.isAdmin
                    showReturn: LibraryService.isLoggedIn && !LibraryService.isAdmin
                    onBorrowRequested: page.doBorrow(book)
                    onReturnRequested: page.doReturn(book)
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: page.results.length === 0
                iconSource: keywordField.text.length > 0 ? FluentIcons.Search : FluentIcons.Library
                title: keywordField.text.length > 0
                       ? I18n.t("没有找到匹配的图书")
                       : I18n.t("馆藏中还没有图书")
                description: keywordField.text.length > 0
                             ? I18n.t("换一个关键词试试，或联系管理员补充馆藏。")
                             : I18n.t("管理员可以在“管理中心”中录入图书，或载入示例数据。")
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

    function ensureLogin(actionName) {
        if (LibraryService.isLoggedIn) {
            return true
        }
        var win = Window.window
        if (win) {
            win.openLogin()
        }
        return false
    }

    function doBorrow(book) {
        if (!ensureLogin("borrow")) {
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

    function doReturn(book) {
        if (!ensureLogin("return")) {
            return
        }
        if (LibraryService.isAdmin) {
            toast(I18n.t("管理员不能自行还书，请在管理中心帮助用户归还"), false)
            return
        }
        var error = LibraryService.returnBook(book.number)
        if (error === "") {
            toast(I18n.f("归还成功：《{0}》", [book.name]), true)
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
