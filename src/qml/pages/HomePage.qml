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

    property string greeting: {
        var hour = new Date().getHours()
        if (hour < 6) {
            return "夜深了"
        }
        if (hour < 12) {
            return "早上好"
        }
        if (hour < 14) {
            return "中午好"
        }
        if (hour < 18) {
            return "下午好"
        }
        return "晚上好"
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 14
        anchors.bottomMargin: 18
        spacing: 16

        FluFrame {
            Layout.fillWidth: true
            Layout.preferredHeight: 168
            radius: 12
            border.width: 0
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 12
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: FluTheme.primaryColor
                    }
                    GradientStop {
                        position: 1.0
                        color: FluTools.withOpacity(FluTheme.primaryColor, 0.62)
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                spacing: 20

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    FluText {
                        text: LibraryService.isLoggedIn
                              ? I18n.f("{0}，{1}", [I18n.t(page.greeting),
                                                   LibraryService.currentDisplayName])
                              : I18n.t("欢迎使用图书管理系统")
                        textColor: "white"
                        font: FluTextStyle.Title
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                    FluText {
                        text: LibraryService.isAdmin
                              ? I18n.t("管理员账号可以管理图书和账户，但不能借阅或归还图书。")
                              : LibraryService.isLoggedIn
                                ? I18n.t("欢迎回来。借阅期限为 1 个月，每本书可以续借一次。")
                                : I18n.t("浏览馆藏无需登录；借阅、续借和查看额度需要先登录。")
                        textColor: Qt.rgba(1, 1, 1, 0.86)
                        font: FluTextStyle.Body
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Item {
                        Layout.preferredHeight: 6
                    }
                    FluButton {
                        text: LibraryService.isLoggedIn
                              ? I18n.t("开始检索图书")
                              : I18n.t("登录")
                        onClicked: {
                            if (LibraryService.isLoggedIn) {
                                page.navigateTo("search")
                            } else {
                                var win = Window.window
                                if (win) {
                                    win.openLogin()
                                }
                            }
                        }
                    }
                }

                Image {
                    source: "qrc:/resources/library.ico"
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 104
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    opacity: 0.95
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            visible: LibraryService.blacklisted
            radius: 8
            color: Qt.rgba(196 / 255, 43 / 255, 28 / 255, 0.10)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 8
                FluIcon {
                    iconSource: FluentIcons.Warning
                    iconSize: 16
                    iconColor: "#D83B3B"
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("你名下有逾期未还图书，已被列入黑名单。归还全部逾期图书后才能继续借阅。")
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
            spacing: 14

            StatCard {
                Layout.fillWidth: true
                title: I18n.t("馆藏图书")
                value: String(LibraryService.stats.totalBooks || 0)
                hint: I18n.t("全部在册图书")
                iconSource: FluentIcons.Library
                accent: FluTheme.primaryColor
            }
            StatCard {
                Layout.fillWidth: true
                title: I18n.t("可借阅")
                value: String(LibraryService.stats.availableBooks || 0)
                hint: I18n.t("当前在馆")
                iconSource: FluentIcons.Completed
                accent: "#2E9B4F"
            }
            StatCard {
                Layout.fillWidth: true
                title: I18n.t("已借出")
                value: String(LibraryService.stats.borrowedBooks || 0)
                hint: I18n.t("全部读者")
                iconSource: FluentIcons.ReadingList
                accent: "#C46A1B"
            }
            StatCard {
                Layout.fillWidth: true
                title: I18n.t("我的借阅")
                value: !LibraryService.isLoggedIn
                       ? "—"
                       : (LibraryService.isAdmin
                          ? "—"
                          : (LibraryService.myBorrowCount || 0) + " / " + LibraryService.borrowLimit)
                hint: !LibraryService.isLoggedIn
                      ? I18n.t("登录后查看")
                      : (LibraryService.isAdmin
                         ? I18n.t("管理员不可借阅")
                         : I18n.f("剩余 {0} 本额度",
                                  [LibraryService.stats.myRemaining || 0]))
                iconSource: FluentIcons.Contact
                accent: "#7A5AF8"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            FluFrame {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    FluText {
                        text: I18n.t("快捷操作")
                        font: FluTextStyle.Title
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                {
                                    title: I18n.t("图书检索"),
                                    desc: I18n.t("按书名、作者、分类或索书号查找馆藏"),
                                    icon: FluentIcons.Search,
                                    route: "search"
                                },
                                {
                                    title: I18n.t("借阅图书"),
                                    desc: I18n.t("借阅期限 1 个月，可续借一次"),
                                    icon: FluentIcons.ReadingList,
                                    route: "borrow"
                                },
                                {
                                    title: I18n.t("归还图书"),
                                    desc: I18n.t("归还当前账号名下的图书"),
                                    icon: FluentIcons.Completed,
                                    route: "return"
                                }
                            ]

                            FluFrame {
                                id: quickCard
                                width: parent.width
                                height: 64
                                radius: 8
                                border.width: 1
                                border.color: quickCard.cardHovered
                                              ? FluTools.withOpacity(FluTheme.primaryColor, 0.45)
                                              : FluTheme.dividerColor
                                color: quickCard.cardHovered
                                       ? FluTools.withOpacity(FluTheme.primaryColor, 0.06)
                                       : (FluTheme.dark ? Qt.rgba(1, 1, 1, 0.02)
                                                        : Qt.rgba(1, 1, 1, 0.7))
                                property bool cardHovered: false

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: quickCard.cardHovered = true
                                    onExited: quickCard.cardHovered = false
                                    onClicked: page.navigateTo(modelData.route)
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 14
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 38
                                        Layout.preferredHeight: 38
                                        radius: 9
                                        color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                                        FluIcon {
                                            anchors.centerIn: parent
                                            iconSource: modelData.icon
                                            iconSize: 18
                                            iconColor: FluTheme.primaryColor
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        FluText {
                                            text: modelData.title
                                            font: FluTextStyle.BodyStrong
                                            Layout.fillWidth: true
                                        }
                                        FluText {
                                            text: modelData.desc
                                            font: FluTextStyle.Caption
                                            textColor: FluTheme.fontSecondaryColor
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    FluIcon {
                                        iconSource: FluentIcons.ChevronRight
                                        iconSize: 12
                                        iconColor: FluTheme.fontTertiaryColor
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            FluFrame {
                Layout.preferredWidth: 320
                Layout.fillHeight: true
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        FluIcon {
                            iconSource: FluentIcons.Info
                            iconSize: 16
                            iconColor: FluTheme.primaryColor
                        }
                        FluText {
                            text: I18n.t("借阅规则")
                            font: FluTextStyle.Title
                        }
                    }

                    FluDivider {
                        Layout.fillWidth: true
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 12

                        Repeater {
                            model: [
                                I18n.f("每位读者最多可同时借阅 {0} 本图书",
                                       [LibraryService.borrowLimit]),
                                I18n.t("借阅期限为 1 个月，每本图书只能续借一次"),
                                I18n.t("逾期未还会被列入黑名单，无法继续借阅"),
                                I18n.t("管理员不能借书或还书，只能在管理中心帮助用户归还"),
                                I18n.t("管理员可以锁定账户、重置密码和查看借阅历史")
                            ]

                            Row {
                                width: parent.width
                                spacing: 8
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: FluTheme.primaryColor
                                }
                                FluText {
                                    width: parent.width - 14
                                    text: modelData
                                    font: FluTextStyle.Body
                                    textColor: FluTheme.fontSecondaryColor
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 108
                        radius: 8
                        color: FluTools.withOpacity(FluTheme.primaryColor, 0.08)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 3

                            FluText {
                                text: LibraryService.isLoggedIn
                                      ? I18n.t("当前账户")
                                      : I18n.t("访客模式")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                Layout.fillWidth: true
                                text: LibraryService.isLoggedIn
                                      ? LibraryService.currentDisplayName + " · "
                                        + (LibraryService.isAdmin
                                           ? I18n.t("管理员")
                                           : I18n.t("读者"))
                                      : I18n.t("登录后可以借阅图书")
                                font: FluTextStyle.BodyStrong
                                elide: Text.ElideRight
                            }
                            FluText {
                                Layout.fillWidth: true
                                visible: LibraryService.isLoggedIn
                                text: LibraryService.isAdmin
                                      ? I18n.t("管理员不能借阅，只能管理图书和用户")
                                      : I18n.f("已借 {0} 本，剩余 {1} 本",
                                               [LibraryService.myBorrowCount,
                                                LibraryService.stats.myRemaining])
                                font: FluTextStyle.Caption
                                textColor: LibraryService.blacklisted
                                             ? "#D83B3B" : FluTheme.fontSecondaryColor
                                elide: Text.ElideRight
                            }
                            FluTextButton {
                                visible: !LibraryService.isLoggedIn
                                text: I18n.t("登录")
                                onClicked: {
                                    var win = Window.window
                                    if (win) {
                                        win.openLogin()
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    FluText {
                        text: I18n.t("数据加密保存在本地 SQLite 数据库，退出程序不会丢失。")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontTertiaryColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    function navigateTo(route) {
        var win = Window.window
        if (win && win.goToPage) {
            win.goToPage(route)
        }
    }
}
