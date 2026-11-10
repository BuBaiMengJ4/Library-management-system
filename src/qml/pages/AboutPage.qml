import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../components"

FluContentPage {
    id: page
    title: "关于"


    property string feedbackUrl: "https://forms.office.com/Pages/ResponsePage.aspx?id=DQSIkWdsW0yxEjajBLZtrQAAAAAAAAAAAAN__jFEEqlUMVhLU0RFSE0yOUxLUlRMSDAzUDRQQUJTMS4u"
    property string repositoryUrl: "https://github.com/BuBaiMengJ4/Library-management-system"

    Flickable {
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentHeight: content.implicitHeight + 48
        ScrollBar.vertical: FluScrollBar {}

        ColumnLayout {
            id: content
            x: 24
            width: parent.width - 48
            spacing: 16

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 196
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
                    spacing: 22

                    Image {
                        source: "qrc:/resources/library.ico"
                        Layout.preferredWidth: 96
                        Layout.preferredHeight: 96
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        FluText {
                            text: "图书管理系统"
                            textColor: "white"
                            font: FluTextStyle.TitleLarge
                        }
                        FluText {
                            text: "Vision 1.0（正式版） · Qt QML 重构版"
                            textColor: Qt.rgba(1, 1, 1, 0.88)
                            font: FluTextStyle.Body
                        }
                        FluText {
                            text: "一个用于借阅与归还、账户管理和馆藏检索的桌面图书管理程序。"
                            textColor: Qt.rgba(1, 1, 1, 0.78)
                            font: FluTextStyle.Caption
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.topMargin: 4
                            spacing: 8
                            Rectangle {
                                width: 96
                                height: 24
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.18)
                                FluText {
                                    anchors.centerIn: parent
                                    text: "开源 · Windows"
                                    textColor: "white"
                                    font: FluTextStyle.Caption
                                }
                            }
                            Rectangle {
                                width: 112
                                height: 24
                                radius: 4
                                color: Qt.rgba(1, 1, 1, 0.18)
                                FluText {
                                    anchors.centerIn: parent
                                    text: "FluentUI 1.7.7"
                                    textColor: "white"
                                    font: FluTextStyle.Caption
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        FluText {
                            text: "作者"
                            textColor: Qt.rgba(1, 1, 1, 0.65)
                            font: FluTextStyle.Caption
                            Layout.alignment: Qt.AlignRight
                        }
                        FluText {
                            text: "BuBaiMengJ4"
                            textColor: "white"
                            font: FluTextStyle.BodyStrong
                            Layout.alignment: Qt.AlignRight
                        }
                        FluText {
                            text: "xiaoyu1145"
                            textColor: "white"
                            font: FluTextStyle.BodyStrong
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8

                    FluText {
                        text: "项目简介"
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: "本程序最初是一个基于命令行的 C++ 图书管理作业（Vision 1.0）。重构版本保留了原有的登录、借书、还书、检索与管理员功能，并将界面迁移到 Qt 6 QML + FluentUI，使用 CMake 构建。"
                        font: FluTextStyle.Body
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    FluText {
                        text: "旧版 control 文本数据会在首次运行时自动迁移到加密的 SQLite 数据库，原始文件不会被修改。"
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontTertiaryColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 264
                    radius: 10
                    border.width: 1
                    border.color: FluTheme.dividerColor
                    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10

                        FluText {
                            text: "功能一览"
                            font: FluTextStyle.Title
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    "账户登录与管理员权限",
                                    "按书名、作者、出版社或索书号检索",
                                    "借书、还书与每人 12 本借阅上限",
                                    "管理员录入图书、创建账户、重置密码",
                                    "SQLite 加密存储与旧版数据迁移",
                                    "深色 / 浅色主题与 Fluent Design 界面"
                                ]

                                Row {
                                    width: parent.width
                                    spacing: 10
                                    FluIcon {
                                        iconSource: FluentIcons.CheckMark
                                        iconSize: 14
                                        iconColor: "#2E9B4F"
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    FluText {
                                        width: parent.width - 28
                                        text: modelData
                                        font: FluTextStyle.Body
                                        color: FluTheme.fontPrimaryColor
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }

                FluFrame {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 264
                    radius: 10
                    border.width: 1
                    border.color: FluTheme.dividerColor
                    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 10

                        FluText {
                            text: "技术架构"
                            font: FluTextStyle.Title
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 8

                            FluText {
                                text: "界面框架"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "Qt 6 QML + FluentUI 1.7.7"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: "构建系统"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "CMake 3.21+ / MinGW 13"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: "业务核心"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "C++17 + QML 单例服务"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: "数据存储"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "SQLite + AES-256-GCM"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: "运行平台"
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "Windows 10 / 11（64 位）"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        FluText {
                            text: "重构自 Vision 1.0（CMD + MSVC）"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontTertiaryColor
                        }
                    }
                }
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: faqColumn.implicitHeight + 44
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                ColumnLayout {
                    id: faqColumn
                    anchors.fill: parent
                    anchors.margins: 22
                    spacing: 10

                    FluText {
                        text: "常见问题"
                        font: FluTextStyle.Title
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                {
                                    q: "管理员默认账号是什么？",
                                    a: "用户名为 Administrator，初始密码为 114514。登录后可以在“管理中心 → 用户管理”中创建读者账户或重置密码。"
                                },
                                {
                                    q: "借阅规则是怎样的？",
                                    a: "每位读者最多同时借阅 12 本图书；每本图书同一时间只能被一位读者借阅。归还后额度立即恢复。"
                                },
                                {
                                    q: "数据保存在哪里？",
                                    a: "数据保存在当前 Windows 用户应用数据目录下的加密 SQLite 数据库中（library.db），主密钥由 DPAPI 保护的 library.key 管理。管理员可以在“管理中心 → 数据与示例”中查看路径、复制路径或打开所在文件夹。"
                                },
                                {
                                    q: "旧版 control 数据还能用吗？",
                                    a: "可以。首次启动且数据库中还没有账户时，程序会读取旧版 book.control、user.control、pass.control 等文件，加密后迁移到 SQLite 数据库，原始文件不会被修改。"
                                },
                                {
                                    q: "忘记密码怎么办？",
                                    a: "请联系管理员，在“管理中心 → 用户管理”中选中账户并重置密码。管理员自己的密码也可以通过同一入口重置。"
                                }
                            ]

                            FluExpander {
                                width: parent.width
                                height: implicitHeight
                                headerText: modelData.q
                                contentHeight: 92

                                FluText {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    text: modelData.a
                                    font: FluTextStyle.Body
                                    textColor: FluTheme.fontSecondaryColor
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }
            }

            FluFrame {
                Layout.fillWidth: true
                Layout.preferredHeight: 104
                radius: 10
                border.width: 1
                border.color: FluTheme.dividerColor
                color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        FluText {
                            text: "反馈与贡献"
                            font: FluTextStyle.BodyStrong
                        }
                        FluText {
                            text: "遇到问题或有改进建议？欢迎通过反馈表单或 GitHub 告诉我们。"
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    FluFilledButton {
                        text: "发送反馈"
                        onClicked: Qt.openUrlExternally(page.feedbackUrl)
                    }
                    FluButton {
                        text: "GitHub 仓库"
                        onClicked: Qt.openUrlExternally(page.repositoryUrl)
                    }
                }
            }

            FluText {
                text: "© 2024-2026 BuBaiMengJ4 & xiaoyu1145 · 本项目为开源学习项目"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
