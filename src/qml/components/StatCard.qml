import QtQuick
import QtQuick.Layouts
import FluentUI 1.0

FluFrame {
    id: control
    property string title: ""
    property string value: "0"
    property string hint: ""
    property int iconSource: FluentIcons.Library
    property color accent: FluTheme.primaryColor

    implicitWidth: 200
    implicitHeight: 108
    radius: 10
    border.width: 1
    border.color: FluTheme.dividerColor
    color: FluTheme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(1, 1, 1, 0.92)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            radius: 10
            color: FluTools.withOpacity(control.accent, 0.14)
            FluIcon {
                anchors.centerIn: parent
                iconSource: control.iconSource
                iconSize: 20
                iconColor: control.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            FluText {
                text: control.title
                font: FluTextStyle.Caption
                textColor: FluTheme.fontSecondaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            FluText {
                text: control.value
                font: FluTextStyle.TitleLarge
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            FluText {
                text: control.hint
                visible: control.hint !== ""
                font: FluTextStyle.Caption
                textColor: FluTheme.fontTertiaryColor
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
