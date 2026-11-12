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
                            text: I18n.t("图书管理系统")
                            textColor: "white"
                            font: FluTextStyle.TitleLarge
                        }
                        FluText {
                            text: I18n.t("Vision 1.0（正式版） · Qt QML 重构版")
                            textColor: Qt.rgba(1, 1, 1, 0.88)
                            font: FluTextStyle.Body
                        }
                        FluText {
                            text: I18n.t("一个用于借阅与归还、账户管理和馆藏检索的桌面图书管理程序。")
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
                                    text: I18n.t("开源 · Windows")
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
                            text: I18n.t("作者")
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
                        text: I18n.t("项目简介")
                        font: FluTextStyle.Title
                    }
                    FluText {
                        text: I18n.t("浏览馆藏无需登录；借阅、续借、归还和管理需要登录。程序使用 Qt 6 QML + FluentUI，并通过 CMake 构建。")
                        font: FluTextStyle.Body
                        textColor: FluTheme.fontSecondaryColor
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                    }
                    FluText {
                        text: I18n.t("旧版 control 文本数据会在首次运行时自动迁移到加密的 SQLite 数据库，原始文件不会被修改。")
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
                            text: I18n.t("功能一览")
                            font: FluTextStyle.Title
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: [
                                    I18n.t("免登录浏览、图书检索与按分类筛选"),
                                    I18n.t("借阅期限 1 个月，每本可续借一次"),
                                    I18n.t("每人最多 12 本；逾期未还进入黑名单"),
                                    I18n.t("管理员管理图书、账户、帮助归还和锁定账户"),
                                    I18n.t("密码 PBKDF2 哈希、5 次失败临时锁定 10 分钟"),
                                    I18n.t("SQLite 加密存储、六种界面语言")
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
                            text: I18n.t("技术架构")
                            font: FluTextStyle.Title
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            columns: 2
                            columnSpacing: 24
                            rowSpacing: 8

                            FluText {
                                text: I18n.t("界面框架")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "Qt 6 QML + FluentUI 1.7.7"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: I18n.t("构建系统")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "CMake 3.21+ / MinGW 13"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: I18n.t("业务核心")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: I18n.t("C++17 + QML 单例服务")
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                            FluText {
                                text: I18n.t("数据存储")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: "SQLite / AES / PBKDF2"
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                            FluText {
                                text: I18n.t("运行平台")
                                font: FluTextStyle.Caption
                                textColor: FluTheme.fontSecondaryColor
                            }
                            FluText {
                                text: I18n.t("Windows / macOS / Linux（64 位）")
                                font: FluTextStyle.Body
                                Layout.fillWidth: true
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        FluText {
                            text: I18n.t("重构自 Vision 1.0（CMD + MSVC）")
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
                        text: I18n.t("常见问题")
                        font: FluTextStyle.Title
                    }

                    Column {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                {
                                    q: "管理员默认账号是什么？",
                                    a: "用户名为 Administrator，初始密码为 114514。首次登录后必须立即设置符合复杂度要求的新密码。"
                                },
                                {
                                    q: "借阅规则是怎样的？",
                                    a: "浏览馆藏无需登录，借阅需要登录。每位读者最多同时借阅 12 本；借阅期限为 1 个月，每本可续借一次。逾期未还会被列入黑名单，无法继续借阅。"
                                },
                                {
                                    q: "管理员可以借书或还书吗？",
                                    a: "管理员账号不能自行借书或还书。管理员可以在“管理中心 → 图书管理”中查看借阅历史、帮助用户归还，或把记录标记为未还。"
                                },
                                {
                                    q: "账户被锁定怎么办？",
                                    a: "密码连续输错 5 次会临时锁定 10 分钟；管理员也可以手动锁定账户。被锁定的账户不能登录，需要等待临时锁定结束或由管理员解锁。"
                                },
                                {
                                    q: "密码是如何保存的？",
                                    a: "密码只保存 PBKDF2-HMAC-SHA256 哈希，不能还原为原文。管理员不能查看用户密码，只能重置；管理员首次登录必须修改密码，普通读者可在个人资料中自行修改。"
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
                                    q: "支持哪些界面语言？",
                                    a: "支持简体中文、繁体中文、英语、日语、德语、俄语和韩语，可在标题栏的语言按钮中切换。"
                                }
                            ]

                            FluExpander {
                                width: parent.width
                                height: implicitHeight
                                headerText: I18n.t(modelData.q)
                                contentHeight: 116

                                FluText {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    text: I18n.t(modelData.a)
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
                            text: I18n.t("反馈与贡献")
                            font: FluTextStyle.BodyStrong
                        }
                        FluText {
                            text: I18n.t("遇到问题或有改进建议？欢迎通过反馈表单或 GitHub 告诉我们。")
                            font: FluTextStyle.Caption
                            textColor: FluTheme.fontSecondaryColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    FluFilledButton {
                        text: I18n.t("发送反馈")
                        onClicked: page.openLink(page.feedbackUrl)
                    }
                    FluButton {
                        text: I18n.t("GitHub 仓库")
                        onClicked: page.openLink(page.repositoryUrl)
                    }
                }
            }

            FluText {
                text: I18n.t("© 2024-2026 BuBaiMengJ4 & xiaoyu1145 · 本项目为开源学习项目")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    function openLink(url) {
        if (!LibraryService.openExternalUrl(url)) {
            var win = Window.window
            if (win && win.showError) {
                win.showError(I18n.t("无法打开浏览器，请手动访问链接"))
            }
        }
    }
}
