import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "首页"

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
                        text: page.greeting + "，" + LibraryService.currentUsername
                        textColor: "white"
                        font: FluTextStyle.TitleLarge
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    FluText {
                        text: "欢迎回到图书管理系统。今天想读点什么？"
                        textColor: Qt.rgba(1, 1, 1, 0.86)
                        font: FluTextStyle.Body
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Item {
                        Layout.preferredHeight: 6
                    }
                    FluButton {
                        text: "开始检索图书"
                        onClicked: page.navigateTo("search")
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

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            StatCard {
                Layout.fillWidth: true
                title: "馆藏图书"
                value: String(LibraryService.stats.totalBooks || 0)
                hint: "全部在册图书"
                iconSource: FluentIcons.Library
                accent: FluTheme.primaryColor
            }
            StatCard {
                Layout.fillWidth: true
                title: "可借阅"
                value: String(LibraryService.stats.availableBooks || 0)
                hint: "当前在馆"
                iconSource: FluentIcons.Completed
                accent: "#2E9B4F"
            }
            StatCard {
                Layout.fillWidth: true
                title: "已借出"
                value: String(LibraryService.stats.borrowedBooks || 0)
                hint: "全部读者"
                iconSource: FluentIcons.ReadingList
                accent: "#C46A1B"
            }
            StatCard {
                Layout.fillWidth: true
                title: "我的借阅"
                value: (LibraryService.myBorrowCount || 0) + " / " + LibraryService.borrowLimit
                hint: "剩余 " + (LibraryService.stats.myRemaining || 0) + " 本额度"
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
                        text: "快捷操作"
                        font: FluTextStyle.Title
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 10

                        Repeater {
                            model: [
                                {
                                    title: "图书检索",
                                    desc: "按书名、作者、出版社或索书号查找馆藏",
                                    icon: FluentIcons.Search,
                                    route: "search"
                                },
                                {
                                    title: "借阅图书",
                                    desc: "输入索书号，或从可借列表中挑选",
                                    icon: FluentIcons.ReadingList,
                                    route: "borrow"
                                },
                                {
                                    title: "归还图书",
                                    desc: "归还当前账号名下的图书",
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
                                       : (FluTheme.dark ? Qt.rgba(1, 1, 1, 0.02) : Qt.rgba(1, 1, 1, 0.7))
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
                            text: "借阅规则"
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
                                "每位读者最多可同时借阅 " + LibraryService.borrowLimit + " 本图书",
                                "每本图书同一时间仅可被一位读者借阅",
                                "归还图书后，借阅额度立即恢复",
                                "管理员可以录入图书、创建账户并重置密码"
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
                        Layout.preferredHeight: 76
                        radius: 8
                        color: FluTools.withOpacity(FluTheme.primaryColor, 0.08)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 2
                            FluText {
                                text: "当前账户"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: LibraryService.currentUsername + " · " + (LibraryService.isAdmin ? "管理员" : "读者")
                                font: FluTextStyle.BodyStrong
                            }
                            FluText {
                                text: "已借 " + LibraryService.myBorrowCount + " 本，剩余 "
                                      + LibraryService.stats.myRemaining + " 本"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    FluText {
                        text: "数据加密保存在本地 SQLite 数据库，退出程序不会丢失。"
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
