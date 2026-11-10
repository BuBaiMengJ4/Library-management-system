import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0
// 管理页的三个标签组件位于 qml/pages/admin。
import "admin"

FluContentPage {
    id: page
    title: "管理中心"

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
                text: "仅管理员可见。图书、账户和借阅数据都会立即加密保存到数据库。"
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        FluPivot {
            Layout.fillWidth: true
            Layout.fillHeight: true
            font: FluTextStyle.Title
            FluPivotItem {
                title: "图书管理"
                contentItem: Component {
                    BookAdminTab {
                    }
                }
            }

            FluPivotItem {
                title: "用户管理"
                contentItem: Component {
                    UserAdminTab {
                    }
                }
            }

            FluPivotItem {
                title: "数据与示例"
                contentItem: Component {
                    DataTab {
                    }
                }
            }
        }
    }
}
