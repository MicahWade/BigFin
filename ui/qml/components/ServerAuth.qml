import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.ScrollablePage {
    id: authPage
    title: "Connect to Jellyfin Server"

    signal loginSuccess()

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.5, 650)
        spacing: 24

        // Logo Header
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Rectangle {
                width: 64
                height: 64
                radius: 32
                color: "#00a4dc"

                Text {
                    anchors.centerIn: parent
                    text: "B"
                    font.pixelSize: 36
                    font.bold: true
                    color: "#ffffff"
                }
            }

            ColumnLayout {
                Text {
                    text: "Bigfin"
                    font.pixelSize: 36
                    font.bold: true
                    color: "#ffffff"
                }

                Text {
                    text: "Native Plasma Bigscreen Media Client"
                    font.pixelSize: 16
                    color: "#a0a5ba"
                }
            }
        }

        Item { Layout.preferredHeight: 12 }

        // Server Address Input Field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Server Address"
                font.pixelSize: 18
                color: "#c0c5d6"
                font.bold: true
            }

            TextField {
                id: serverField
                Layout.fillWidth: true
                text: root.serverUrl
                placeholderText: "http://192.168.1.100:8096"
                font.pixelSize: 20
                padding: 14
                focus: true
                activeFocusOnTab: true

                background: Rectangle {
                    color: serverField.activeFocus ? "#252b42" : "#161928"
                    border.color: serverField.activeFocus ? "#00a4dc" : "#2d334a"
                    border.width: serverField.activeFocus ? 3 : 1
                    radius: 8

                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                KeyNavigation.down: usernameField
            }
        }

        // Username Input Field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Username"
                font.pixelSize: 18
                color: "#c0c5d6"
                font.bold: true
            }

            TextField {
                id: usernameField
                Layout.fillWidth: true
                placeholderText: "Enter username"
                font.pixelSize: 20
                padding: 14
                activeFocusOnTab: true

                background: Rectangle {
                    color: usernameField.activeFocus ? "#252b42" : "#161928"
                    border.color: usernameField.activeFocus ? "#00a4dc" : "#2d334a"
                    border.width: usernameField.activeFocus ? 3 : 1
                    radius: 8

                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                KeyNavigation.up: serverField
                KeyNavigation.down: passwordField
            }
        }

        // Password Input Field
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Password"
                font.pixelSize: 18
                color: "#c0c5d6"
                font.bold: true
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                placeholderText: "Enter password"
                echoMode: TextInput.Password
                font.pixelSize: 20
                padding: 14
                activeFocusOnTab: true

                background: Rectangle {
                    color: passwordField.activeFocus ? "#252b42" : "#161928"
                    border.color: passwordField.activeFocus ? "#00a4dc" : "#2d334a"
                    border.width: passwordField.activeFocus ? 3 : 1
                    radius: 8

                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                KeyNavigation.up: usernameField
                KeyNavigation.down: connectBtn
            }
        }

        Item { Layout.preferredHeight: 12 }

        // Connect Button
        Button {
            id: connectBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            activeFocusOnTab: true

            contentItem: Text {
                text: "Connect & Sign In"
                font.pixelSize: 20
                font.bold: true
                color: "#ffffff"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: connectBtn.activeFocus ? "#00bdff" : "#008ac4"
                radius: 10
                scale: connectBtn.activeFocus ? 1.03 : 1.0

                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            KeyNavigation.up: passwordField

            onClicked: {
                root.serverUrl = serverField.text
                root.username = usernameField.text
                authPage.loginSuccess()
            }
        }
    }
}
