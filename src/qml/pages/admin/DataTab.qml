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
            title: "馆藏图书"
            value: String(LibraryService.stats.totalBooks || 0)
            hint: "本"
            iconSource: FluentIcons.Library
        }
        StatCard {
            Layout.fillWidth: true
            title: "借出图书"
            value: String(LibraryService.stats.borrowedBooks || 0)
            hint: "本"
            iconSource: FluentIcons.ReadingList
            accent: "#C46A1B"
        }
        StatCard {
            Layout.fillWidth: true
            title: "注册账户"
            value: String(LibraryService.stats.totalUsers || 0)
            hint: "含管理员"
            iconSource: FluentIcons.People
            accent: "#7A5AF8"
        }
    }

    FluFrame {
        Layout.fillWidth: true
        Layout.preferredHeight: 196
        radius: 10
        border.width: 1
        border.color: FluTheme.dividerColor
        color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            FluText {
                text: "数据库文件"
                font: FluTextStyle.Title
            }
            FluText {
                text: "全部图书、账户和借阅记录都保存在加密的 SQLite 数据库中，退出程序不会丢失。账户与图书字段使用 AES-256-GCM 独立加密。"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                wrapMode: Text.Wrap
            }
            FluText {
                text: "主密钥由 Windows DPAPI 以当前用户为范围保护，保存在同目录的 library.key 中。"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
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
                    text: "复制路径"
                    onClicked: {
                        FluTools.clipText(LibraryService.databasePath)
                        tab.toast("数据库路径已复制到剪贴板", true)
                    }
                }

                FluButton {
                    text: "打开所在文件夹"
                    onClicked: FluTools.showFileInFolder(LibraryService.databasePath)
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
                    text: "示例数据"
                    font: FluTextStyle.Title
                }
                FluText {
                    text: "载入 12 本中外经典图书，方便快速体验检索、借阅和归还流程。已存在的同名图书会被跳过。"
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                }
            }

            FluFilledButton {
                Layout.preferredWidth: 150
                text: "载入示例图书"
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
                    text: "旧版数据迁移完成"
                    font: FluTextStyle.BodyStrong
                }
                FluText {
                    text: LibraryService.migrationNote + "。原始 control 文件没有被修改。"
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                    Layout.fillWidth: true
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
            toast("已载入 " + count + " 本示例图书", true)
        } else if (LibraryService.lastError !== "") {
            toast(LibraryService.lastError, false)
        } else {
            toast("示例图书已存在，无需重复载入", true)
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
            win.showError(message)
        }
    }
}
