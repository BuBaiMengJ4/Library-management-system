import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtCore
import FluentUI 1.0
import Library 1.0
import "components"
import "dialogs"

FluWindow {
    id: window
    width: Math.min(1280, Screen.desktopAvailableWidth - 80)
    height: Math.min(820, Screen.desktopAvailableHeight - 80)
    minimumWidth: Math.min(980, Screen.desktopAvailableWidth - 80)
    minimumHeight: Math.min(680, Screen.desktopAvailableHeight - 80)
    title: I18n.t("图书管理系统")
    showDark: true

    property var pageStack: [{ route: "home", titleKey: "首页" }]
    property string currentTitleKey: "首页"

    appBar: TitleBar {
        titleKey: window.currentTitleKey
        canGoBack: window.pageStack.length > 1
        onBackRequested: window.goBack()
        onLoginRequested: window.openLogin()
        onProfileRequested: window.openProfile()
        onLanguageRequested: languageDialog.open()
        onLogoutRequested: logoutDialog.open()
    }

    Settings {
        id: uiSettings
        category: "ui"
        property string language: "zh_CN"
    }

    FluNavigationView {
        id: nav
        anchors.fill: parent
        hideNavAppBar: true
        navTopMargin: 6
        displayMode: FluNavigationViewType.Auto

        items: FluObject {
            FluPaneItem {
                title: I18n.t("首页")
                icon: FluentIcons.Home
                url: "qrc:/qml/pages/HomePage.qml"
                extra: "home"
                onTap: window.openPage(url, "home", "首页")
            }
            FluPaneItem {
                title: I18n.t("图书检索")
                icon: FluentIcons.Search
                url: "qrc:/qml/pages/SearchPage.qml"
                extra: "search"
                onTap: window.openPage(url, "search", "图书检索")
            }
            FluPaneItem {
                title: I18n.t("借阅图书")
                icon: FluentIcons.ReadingList
                url: "qrc:/qml/pages/BorrowPage.qml"
                extra: "borrow"
                onTap: window.openPage(url, "borrow", "借阅图书")
            }
            FluPaneItem {
                title: I18n.t("归还图书")
                icon: FluentIcons.Completed
                url: "qrc:/qml/pages/ReturnPage.qml"
                extra: "return"
                onTap: window.openPage(url, "return", "归还图书")
            }
            FluPaneItem {
                title: I18n.t("我的借阅")
                icon: FluentIcons.Bookmarks
                url: "qrc:/qml/pages/MyBooksPage.qml"
                extra: "mybooks"
                onTap: window.openPage(url, "mybooks", "我的借阅")
            }
            FluPaneItem {
                title: I18n.t("管理中心")
                icon: FluentIcons.Admin
                url: "qrc:/qml/pages/AdminPage.qml"
                extra: "admin"
                visible: LibraryService.isAdmin
                onTap: window.openPage(url, "admin", "管理中心")
            }
            FluPaneItem {
                title: I18n.t("关于")
                icon: FluentIcons.Info
                url: "qrc:/qml/pages/AboutPage.qml"
                extra: "about"
                onTap: window.openPage(url, "about", "关于")
            }
        }

        footerItems: FluObject {
            FluPaneItemSeparator {
                spacing: 6
            }
        }

        Component.onCompleted: {
            Qt.callLater(function() {
                nav.setCurrentIndex(0)
            })
        }
    }

    LoginDialog {
        id: loginDialog
        onLoggedIn: window.afterLogin()
    }

    ChangePasswordDialog {
        id: changePasswordDialog
    }

    ProfileDialog {
        id: profileDialog
        onPasswordChangeRequested: {
            changePasswordDialog.forced = false
            changePasswordDialog.open()
        }
        onLogoutRequested: logoutDialog.open()
    }

    LanguageDialog {
        id: languageDialog
        onLanguageSelected: function(code) {
            I18n.language = code
            uiSettings.language = code
        }
    }

    FluContentDialog {
        id: logoutDialog
        title: I18n.t("退出登录")
        message: I18n.t("确定要退出当前账号吗？未归还的借阅记录会保留。")
        positiveText: I18n.t("退出")
        negativeText: I18n.t("取消")
        onPositiveClicked: {
            logoutDialog.close()
            Qt.callLater(window.logout)
        }
    }

    Shortcut { sequence: "Ctrl+1"; onActivated: window.goToPage("home") }
    Shortcut { sequence: "Ctrl+2"; onActivated: window.goToPage("search") }
    Shortcut { sequence: "Ctrl+3"; onActivated: window.goToPage("borrow") }
    Shortcut { sequence: "Ctrl+4"; onActivated: window.goToPage("return") }
    Shortcut { sequence: "Ctrl+5"; onActivated: window.goToPage("mybooks") }
    Shortcut { sequence: "Ctrl+6"; onActivated: window.goToPage("admin") }
    Shortcut { sequence: "Ctrl+7"; onActivated: window.goToPage("about") }
    Shortcut { sequence: "Ctrl+L"; onActivated: languageDialog.open() }
    Shortcut { sequence: "Ctrl+P"; onActivated: window.openProfile() }

    Component.onCompleted: {
        I18n.language = uiSettings.language
    }

    function openPage(url, route, titleKey) {
        if (pageStack.length === 0
            || pageStack[pageStack.length - 1].route !== route) {
            pageStack = pageStack.concat([{ route: route, titleKey: titleKey }])
        }
        currentTitleKey = titleKey
        nav.push(url)
    }

    function goToPage(route) {
        var items = nav.getItems()
        for (var i = 0; i < items.length; ++i) {
            if (items[i] && items[i].extra === route) {
                nav.setCurrentIndex(i)
                return
            }
        }
    }

    function goBack() {
        if (pageStack.length <= 1) {
            return
        }
        pageStack = pageStack.slice(0, -1)
        currentTitleKey = pageStack[pageStack.length - 1].titleKey
        if (!nav.buttonBack.disabled) {
            nav.buttonBack.clicked()
        }
    }

    function openLogin() {
        if (LibraryService.isLoggedIn) {
            return
        }
        loginDialog.open()
    }

    function openProfile() {
        if (!LibraryService.isLoggedIn) {
            openLogin()
            return
        }
        profileDialog.open()
    }

    function afterLogin() {
        if (LibraryService.mustChangePassword) {
            changePasswordDialog.forced = true
            changePasswordDialog.open()
        }
    }

    function logout() {
        LibraryService.logout()
        pageStack = [{ route: "home", titleKey: "首页" }]
        currentTitleKey = "首页"
        goToPage("home")
    }
}
