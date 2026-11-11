import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 380
    implicitHeight: contentColumn.implicitHeight + 48

    signal languageSelected(string code)

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 22
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            FluText {
                Layout.fillWidth: true
                text: I18n.t("界面语言")
                font: FluTextStyle.Title
            }
            FluIconButton {
                iconSource: FluentIcons.ChromeClose
                iconSize: 10
                width: 28
                height: 28
                onClicked: dialog.close()
            }
        }

        Repeater {
            model: I18n.languages

            FluButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                text: (I18n.language === modelData.code ? "✓  " : "    ") + modelData.name
                onClicked: {
                    dialog.languageSelected(modelData.code)
                    dialog.close()
                }
            }
        }

        FluText {
            Layout.fillWidth: true
            Layout.topMargin: 4
            text: I18n.t("切换语言后界面会立即更新。")
            font: FluTextStyle.Caption
            textColor: FluTheme.fontTertiaryColor
        }
    }
}
