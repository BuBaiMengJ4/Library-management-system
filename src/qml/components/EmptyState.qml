import QtQuick
import QtQuick.Layouts
import FluentUI 1.0

Item {
    id: control
    property string title: "暂无数据"
    property string description: ""
    property int iconSource: FluentIcons.Library

    implicitWidth: 420
    implicitHeight: 240
    width: implicitWidth
    height: implicitHeight

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(control.width - 40, 360)
        spacing: 10

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 68
            height: 68
            radius: 34
            color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)
            FluIcon {
                anchors.centerIn: parent
                iconSource: control.iconSource
                iconSize: 28
                iconColor: FluTheme.primaryColor
            }
        }

        FluText {
            text: control.title
            font: FluTextStyle.BodyStrong
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }

        FluText {
            text: control.description
            visible: text !== ""
            font: FluTextStyle.Caption
            textColor: FluTheme.fontSecondaryColor
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
