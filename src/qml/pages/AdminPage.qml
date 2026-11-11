import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
// 管理页的三个标签组件位于 qml/pages/admin。
import "admin"

FluContentPage {
    id: page
    title: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.topMargin: 10
        anchors.bottomMargin: 16
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            FluIcon {
                iconSource: FluentIcons.Admin
                iconSize: 15
                iconColor: FluTheme.primaryColor
            }
            FluText {
                text: I18n.t("仅管理员可见。图书、账户和借阅记录都会立即加密保存到数据库。")
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        FluPivot {
            id: pivot
            Layout.fillWidth: true
            Layout.fillHeight: true
            font: FluTextStyle.Title

            FluPivotItem {
                title: I18n.t("图书管理")
                contentItem: Component {
                    BookAdminTab {
                    }
                }
            }

            FluPivotItem {
                title: I18n.t("用户管理")
                contentItem: Component {
                    UserAdminTab {
                    }
                }
            }

            FluPivotItem {
                title: I18n.t("数据与示例")
                contentItem: Component {
                    DataTab {
                    }
                }
            }
        }
    }

    Shortcut { sequence: "Ctrl+Shift+1"; onActivated: pivot.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+Shift+2"; onActivated: pivot.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+Shift+3"; onActivated: pivot.currentIndex = 2 }
}
