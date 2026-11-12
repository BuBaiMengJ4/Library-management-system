import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import FluentUI 1.0
import Library 1.0

FluPopup {
    id: dialog
    width: 720
    implicitHeight: 640

    property int bookNumber: 0
    property var bookData: ({})

    function openFor(number) {
        bookNumber = number
        bookData = LibraryService.findBook(number)
        open()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 22
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            FluText {
                Layout.fillWidth: true
                text: I18n.t("图书详情")
                font: FluTextStyle.TitleLarge
            }
            FluIconButton {
                iconSource: FluentIcons.ChromeClose
                iconSize: 10
                width: 28
                height: 28
                onClicked: dialog.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 244
            Layout.maximumHeight: 244
            spacing: 20

            Rectangle {
                Layout.preferredWidth: 164
                Layout.preferredHeight: 222
                Layout.maximumHeight: 222
                Layout.alignment: Qt.AlignTop
                radius: 8
                clip: true
                color: FluTools.withOpacity(FluTheme.primaryColor, 0.10)

                Image {
                    id: cover
                    anchors.fill: parent
                    source: dialog.bookData && dialog.bookData.hasCover
                            ? "image://library/cover/" + dialog.bookNumber
                              + "?v=" + LibraryService.imageRevision
                            : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: cover.status !== Image.Ready
                    spacing: 4
                    FluIcon {
                        Layout.alignment: Qt.AlignHCenter
                        iconSource: FluentIcons.Library
                        iconSize: 32
                        iconColor: FluTheme.primaryColor
                    }
                    FluText {
                        Layout.alignment: Qt.AlignHCenter
                        text: dialog.bookData ? (dialog.bookData.numberText || "") : ""
                        font: FluTextStyle.BodyStrong
                        textColor: FluTheme.primaryColor
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 5

                FluText {
                    Layout.fillWidth: true
                    text: dialog.bookData ? (dialog.bookData.name || "") : ""
                    font: FluTextStyle.TitleLarge
                    wrapMode: Text.Wrap
                }
                FluText {
                    Layout.fillWidth: true
                    text: (dialog.bookData ? (dialog.bookData.author || "") : "")
                          + " · " + (dialog.bookData ? (dialog.bookData.publisher || "") : "")
                    font: FluTextStyle.Body
                    textColor: FluTheme.fontSecondaryColor
                    wrapMode: Text.Wrap
                }
                RowLayout {
                    spacing: 12
                    FluText {
                        text: I18n.t("索书号：") + dialog.bookNumber
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: I18n.t("分类：")
                              + (dialog.bookData ? (dialog.bookData.category || "") : "")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                    FluText {
                        text: I18n.t("位置：")
                              + (dialog.bookData ? (dialog.bookData.place || "") : "")
                        font: FluTextStyle.Caption
                        textColor: FluTheme.fontSecondaryColor
                    }
                }
                FluText {
                    text: dialog.bookData && dialog.bookData.available
                          ? I18n.t("当前状态：在馆")
                          : I18n.t("当前状态：已借出")
                    font: FluTextStyle.Caption
                    textColor: dialog.bookData && dialog.bookData.overdue
                               ? "#D83B3B" : FluTheme.primaryColor
                }
                FluText {
                    visible: dialog.bookData && !dialog.bookData.available
                             && (dialog.bookData.isMine === true
                                 || LibraryService.isAdmin)
                    text: I18n.t("借阅人：")
                          + (dialog.bookData ? (dialog.bookData.borrowerDisplayName || "") : "")
                          + (dialog.bookData && dialog.bookData.dueDate
                             ? "  ·  " + I18n.f("应还 {0}", [dialog.bookData.dueDate])
                             : "")
                    font: FluTextStyle.Caption
                    textColor: FluTheme.fontSecondaryColor
                }
            }
        }

        FluDivider {
            Layout.fillWidth: true
        }

        FluText {
            text: I18n.t("图书简介")
            font: FluTextStyle.Title
        }

        Flickable {
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            Layout.minimumHeight: 100
            clip: true
            contentWidth: width
            contentHeight: Math.max(height, descriptionText.implicitHeight)

            FluText {
                id: descriptionText
                width: parent.width
                text: dialog.bookData
                      ? ((dialog.bookData.description || "") !== ""
                         ? dialog.bookData.description
                         : I18n.t("暂无简介"))
                      : ""
                textFormat: Text.MarkdownText
                font: FluTextStyle.Body
                color: FluTheme.fontPrimaryColor
                wrapMode: Text.Wrap
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Item {
                Layout.fillWidth: true
            }
            FluButton {
                text: I18n.t("关闭")
                onClicked: dialog.close()
            }
        }
    }
}
