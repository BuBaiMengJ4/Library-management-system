import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
import "../../components"

ColumnLayout {
    id: tab
    spacing: 14

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        StatCard {
            Layout.fillWidth: true
            title: I18n.t("馆藏图书")
            value: String(LibraryService.stats.totalBooks || 0)
            hint: I18n.t("本")
            iconSource: FluentIcons.Library
        }
        StatCard {
            Layout.fillWidth: true
            title: I18n.t("借出图书")
            value: String(LibraryService.stats.borrowedBooks || 0)
            hint: I18n.t("本")
            iconSource: FluentIcons.ReadingList
            accent: "#C46A1B"
        }
        StatCard {
            Layout.fillWidth: true
            title: I18n.t("逾期未还")
            value: String(LibraryService.stats.overdueBooks || 0)
            hint: I18n.t("本")
            iconSource: FluentIcons.Warning
            accent: "#D83B3B"
        }
        StatCard {
            Layout.fillWidth: true
            title: I18n.t("注册账户")
            value: String(LibraryService.stats.totalUsers || 0)
            hint: I18n.t("含管理员")
            iconSource: FluentIcons.People
            accent: "#7A5AF8"
        }
    }

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 210
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            FluText {
                text: I18n.t("数据库文件")
                font: FluTextStyle.Title
            }
            FluText {
                Layout.fillWidth: true
                text: I18n.t("图书、账户、借阅历史和头像封面都保存在加密 SQLite 数据库中。账户与图书字段使用 AES-256-GCM 独立加密。")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                wrapMode: Text.Wrap
            }
            FluText {
                Layout.fillWidth: true
                text: I18n.t("密码只保存 PBKDF2-HMAC-SHA256 哈希，管理员无法查看原始密码；主密钥由 Windows DPAPI 保护。")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                FluTextBox {
                    Layout.fillWidth: true
                    text: LibraryService.databasePath
                    readOnly: true
                    cleanEnabled: false
                    font: FluTextStyle.Caption
                }

                FluButton {
                    text: I18n.t("复制路径")
                    onClicked: {
                        FluTools.clipText(LibraryService.databasePath)
                        tab.toast(I18n.t("数据库路径已复制到剪贴板"), true)
                    }
                }

                FluButton {
                    text: I18n.t("打开所在文件夹")
                    onClicked: FluTools.showFileInFolder(LibraryService.databasePath)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                FluText {
                    text: I18n.f("借阅记录 {0} 条", [LibraryService.stats.totalLoans || 0])
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
                FluText {
                    text: I18n.f("黑名单用户 {0} 个", [LibraryService.stats.blacklistedUsers || 0])
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
                FluText {
                    text: I18n.f("锁定账户 {0} 个", [LibraryService.stats.lockedUsers || 0])
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
                Item {
                    Layout.fillWidth: true
                }
            }
        }
    }

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 146
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: 12
                color: FluTools.withOpacity(FluTheme.primaryColor, 0.12)
                FluIcon {
                    anchors.centerIn: parent
                    iconSource: FluentIcons.Library
                    iconSize: 22
                    iconColor: FluTheme.primaryColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                FluText {
                    text: I18n.t("示例数据")
                    font: FluTextStyle.Title
                }
                FluText {
                    Layout.fillWidth: true
                    text: I18n.t("载入 12 本中外经典图书，包含分类和简介，方便体验检索、借阅、续借和归还流程。")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    wrapMode: Text.Wrap
                }
            }

            FluFilledButton {
                Layout.preferredWidth: 150
                text: I18n.t("载入示例图书")
                onClicked: tab.seed()
            }
        }
    }

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 76
        visible: LibraryService.migrationNote !== ""
        radius: 8
        border.width: 1
        border.color: FluTools.withOpacity(FluTheme.primaryColor, 0.35)
        color: FluTools.withOpacity(FluTheme.primaryColor, 0.07)

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10
            FluIcon {
                iconSource: FluentIcons.Info
                iconSize: 16
                iconColor: FluTheme.primaryColor
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                FluText {
                    text: I18n.t("旧版数据迁移完成")
                    font: FluTextStyle.BodyStrong
                }
                FluText {
                    Layout.fillWidth: true
                    text: LibraryService.migrationNote + "。"
                          + I18n.t("原始 control 文件没有被修改。")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    elide: Text.ElideRight
                }
            }
        }
    }

    Item {
        Layout.fillHeight: true
    }

    function seed() {
        var count = LibraryService.seedSampleBooks()
        if (count > 0) {
            toast(I18n.f("已载入 {0} 本示例图书", [count]), true)
        } else if (LibraryService.lastError !== "") {
            toast(LibraryService.lastError, false)
        } else {
            toast(I18n.t("示例图书已存在，无需重复载入"), true)
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
