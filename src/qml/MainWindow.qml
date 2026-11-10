import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import FluentUI 1.0
import Library 1.0

FluWindow {
    id: window
    width: Math.min(1280, Screen.desktopAvailableWidth - 80)
    height: Math.min(820, Screen.desktopAvailableHeight - 80)
    minimumWidth: Math.min(980, Screen.desktopAvailableWidth - 80)
    minimumHeight: Math.min(680, Screen.desktopAvailableHeight - 80)
    title: LibraryService.isAdmin ? "图书管理系统 · 管理员" : "图书管理系统"
    showDark: true

    FluNavigationView {
        id: nav
        anchors.fill: parent
        logo: "qrc:/resources/library.ico"
        title: "图书管理系统"
        displayMode: FluNavigationViewType.Auto

        items: FluObject {
            FluPaneItem {
                title: "首页"
                icon: FluentIcons.Home
                url: "qrc:/qml/pages/HomePage.qml"
                extra: "home"
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "图书检索"
                icon: FluentIcons.Search
                url: "qrc:/qml/pages/SearchPage.qml"
                extra: "search"
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "借阅图书"
                icon: FluentIcons.ReadingList
                url: "qrc:/qml/pages/BorrowPage.qml"
                extra: "borrow"
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "归还图书"
                icon: FluentIcons.Completed
                url: "qrc:/qml/pages/ReturnPage.qml"
                extra: "return"
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "我的借阅"
                icon: FluentIcons.Bookmarks
                url: "qrc:/qml/pages/MyBooksPage.qml"
                extra: "mybooks"
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "管理中心"
                icon: FluentIcons.Admin
                url: "qrc:/qml/pages/AdminPage.qml"
                extra: "admin"
                visible: LibraryService.isAdmin
                onTap: nav.push(url)
            }
            FluPaneItem {
                title: "关于"
                icon: FluentIcons.Info
                url: "qrc:/qml/pages/AboutPage.qml"
                extra: "about"
                onTap: nav.push(url)
            }
        }

        footerItems: FluObject {
            FluPaneItemSeparator {
                spacing: 6
            }
            FluPaneItem {
                title: FluTheme.dark ? "切换到浅色模式" : "切换到深色模式"
                icon: FluTheme.dark ? FluentIcons.Brightness : FluentIcons.QuietHours
                onTapListener: function() {
                    FluTheme.darkMode = FluTheme.dark ? FluThemeType.Light : FluThemeType.Dark
                }
            }
            FluPaneItem {
                title: "退出登录"
                icon: FluentIcons.SignOut
                onTapListener: function() {
                    logoutDialog.open()
                }
            }
        }

        actionItem: Component {
            RowLayout {
                height: 40
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: 14
                    color: FluTheme.primaryColor
                    FluText {
                        anchors.centerIn: parent
                        text: LibraryService.currentUsername.length > 0
                              ? LibraryService.currentUsername.charAt(0).toUpperCase()
                              : "?"
                        textColor: "white"
                        font: FluTextStyle.BodyStrong
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0
                    FluText {
                        text: LibraryService.currentUsername
                        font: FluTextStyle.BodyStrong
                    }
                    FluText {
                        text: LibraryService.isAdmin ? "管理员" : "读者"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                }

                Item {
                    Layout.preferredWidth: 12
                }
            }
        }

        Component.onCompleted: {
            Qt.callLater(function() {
                nav.setCurrentIndex(0)
            })
        }
    }

    FluContentDialog {
        id: logoutDialog
        title: "退出登录"
        message: "确定要退出当前账号吗？未归还的借阅记录会保留。"
        positiveText: "退出"
        negativeText: "取消"
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

    function goToPage(route) {
        var items = nav.getItems()
        for (var i = 0; i < items.length; ++i) {
            if (items[i] && items[i].extra === route) {
                nav.setCurrentIndex(i)
                return
            }
        }
    }

    function logout() {
        LibraryService.logout()
        FluRouter.navigate("/login")
        window.close()
    }
}
