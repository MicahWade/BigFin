import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.ScrollablePage {
    id: detailsPage
    title: item ? item.title : "Item Details"

    property var item: null

    signal playRequested(var item)

    ColumnLayout {
        anchors.fill: parent
        spacing: 32

        // Backdrop & Main Info Header
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 450

            // Backdrop Glow Image
            Image {
                anchors.fill: parent
                source: item ? item.posterUrl : ""
                fillMode: Image.PreserveAspectCrop
                opacity: 0.25
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#000f111a" }
                    GradientStop { position: 0.8; color: "#f00f111a" }
                    GradientStop { position: 1.0; color: "#0f111a" }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 36

                // High-res Poster Display
                Rectangle {
                    Layout.preferredWidth: 260
                    Layout.preferredHeight: 390
                    radius: 12
                    color: "#161a29"
                    border.color: "#00a4dc"
                    border.width: 2

                    Image {
                        anchors.fill: parent
                        source: item ? item.posterUrl : ""
                        fillMode: Image.PreserveAspectCrop
                    }
                }

                // Details & Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16

                    Text {
                        text: item ? item.title : ""
                        font.pixelSize: 42
                        font.bold: true
                        color: "#ffffff"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 16

                        Rectangle {
                            height: 28
                            width: 60
                            radius: 6
                            color: "#00a4dc"
                            Text {
                                anchors.centerIn: parent
                                text: item ? item.year : ""
                                font.pixelSize: 14
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        Text {
                            text: "★ " + (item ? item.rating : "N/A")
                            font.pixelSize: 18
                            font.bold: true
                            color: "#ffc107"
                            visible: AppData.isRatingVisible(item)
                        }

                        Text {
                            text: "Direct Play Available (HEVC/AAC)"
                            font.pixelSize: 15
                            color: "#4caf50"
                            font.bold: true
                        }
                    }

                    Text {
                        text: item ? item.overview : ""
                        font.pixelSize: 18
                        color: "#cbd1e0"
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                        Layout.fillWidth: true
                    }

                    Item { Layout.fillHeight: true }

                    // Action Button Row
                    RowLayout {
                        spacing: 20

                        Button {
                            id: playBtn
                            focus: true
                            activeFocusOnTab: true
                            Layout.preferredWidth: 200
                            Layout.preferredHeight: 56

                            contentItem: RowLayout {
                                spacing: 10
                                Layout.alignment: Qt.AlignHCenter
                                Text { text: "▶"; font.pixelSize: 22; color: "#ffffff" }
                                Text { text: "Play Now"; font.pixelSize: 20; font.bold: true; color: "#ffffff" }
                            }

                            background: Rectangle {
                                color: playBtn.activeFocus ? "#00bdff" : "#008ac4"
                                radius: 10
                                scale: playBtn.activeFocus ? 1.05 : 1.0
                                Behavior on scale { NumberAnimation { duration: 120 } }
                            }

                            onClicked: {
                                detailsPage.playRequested(item)
                            }
                            Keys.onReturnPressed: detailsPage.playRequested(item)
                        }

                        Button {
                            id: favoriteBtn
                            activeFocusOnTab: true
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 56

                            contentItem: RowLayout {
                                spacing: 10
                                Layout.alignment: Qt.AlignHCenter
                                Text { text: "♥"; font.pixelSize: 22; color: "#ff4081" }
                                Text { text: "Favorite"; font.pixelSize: 18; color: "#ffffff" }
                            }

                            background: Rectangle {
                                color: favoriteBtn.activeFocus ? "#2a3148" : "#1a1f30"
                                border.color: favoriteBtn.activeFocus ? "#00a4dc" : "#2d344d"
                                border.width: favoriteBtn.activeFocus ? 2 : 1
                                radius: 10
                                scale: favoriteBtn.activeFocus ? 1.05 : 1.0
                            }

                            KeyNavigation.left: playBtn
                        }
                    }
                }
            }
        }
    }
}
