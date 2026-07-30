import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import org.kde.kirigami 2.20 as Kirigami

ApplicationWindow {
    id: testWindow
    title: "Bigfin UI - Standalone Visual Navigation Test Suite"
    width: 1920
    height: 1080
    visible: true

    palette.window: "#0b0e17"
    palette.windowText: "#ffffff"

    property bool showDiagnosticHud: true
    property string lastKeyInput: "None"
    property int totalKeyEvents: 0

    Item {
        id: rootContainer
        anchors.fill: parent
        focus: true

        // Embedded Main Application Shell
        Main {
            id: mainAppShell
            anchors.fill: parent
            focus: true
        }

        // Diagnostic Focus & Input Monitor HUD Overlay
        Rectangle {
            id: hudOverlay
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            width: 440
            height: 280
            radius: 12
            color: "#ee0f172a"
            border.color: "#38bdf8"
            border.width: 2
            z: 999
            visible: testWindow.showDiagnosticHud

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "🛠 DIAGNOSTIC HUD"
                        font.pixelSize: 14
                        font.bold: true
                        color: "#38bdf8"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Press 'D' to Hide"
                        font.pixelSize: 11
                        color: "#94a3b8"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#334155" }

                RowLayout {
                    Text { text: "Active View:"; font.pixelSize: 13; color: "#94a3b8" }
                    Text {
                        text: mainAppShell.currentView.toUpperCase()
                        font.pixelSize: 14
                        font.bold: true
                        color: "#38bdf8"
                    }
                }

                RowLayout {
                    Text { text: "Focused Item:"; font.pixelSize: 13; color: "#94a3b8" }
                    Text {
                        text: testWindow.activeFocusItem ? (testWindow.activeFocusItem.objectName || testWindow.activeFocusItem.toString()) : "None"
                        font.pixelSize: 12
                        color: "#f8fafc"
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    Text { text: "Last Key Input:"; font.pixelSize: 13; color: "#94a3b8" }
                    Text {
                        text: testWindow.lastKeyInput + " (Count: " + testWindow.totalKeyEvents + ")"
                        font.pixelSize: 13
                        font.bold: true
                        color: "#fbbf24"
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#334155" }

                Text {
                    text: "Quick Shortcuts Checklist:"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#f8fafc"
                }

                Text {
                    text: "• Space: Quick Launch Player | Toggle Play\n• H: Jump to Home View\n• G: Jump to Media Grid\n• Esc / Backspace: Back Navigation\n• D: Toggle HUD Overlay"
                    font.pixelSize: 11
                    color: "#cbd5e1"
                    lineHeight: 1.2
                }
            }
        }

        // Diagnostic Keyboard Observer
        Keys.onPressed: function(event) {
            testWindow.totalKeyEvents++
            if (event.key === Qt.Key_D) {
                testWindow.showDiagnosticHud = !testWindow.showDiagnosticHud
                testWindow.lastKeyInput = "Key_D (Toggle HUD)"
                event.accepted = true
            } else if (event.key === Qt.Key_H) {
                mainAppShell.switchView("home")
                testWindow.lastKeyInput = "Key_H (Jump Home)"
                event.accepted = true
            } else if (event.key === Qt.Key_G) {
                mainAppShell.switchView("movies")
                testWindow.lastKeyInput = "Key_G (Jump Grid)"
                event.accepted = true
            } else if (event.key === Qt.Key_P) {
                mainAppShell.currentView = "player"
                testWindow.lastKeyInput = "Key_P (Launch Player)"
                event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                testWindow.lastKeyInput = "Key_Up (D-Pad)"
            } else if (event.key === Qt.Key_Down) {
                testWindow.lastKeyInput = "Key_Down (D-Pad)"
            } else if (event.key === Qt.Key_Left) {
                testWindow.lastKeyInput = "Key_Left (D-Pad)"
            } else if (event.key === Qt.Key_Right) {
                testWindow.lastKeyInput = "Key_Right (D-Pad)"
            } else if (event.key === Qt.Key_Return) {
                testWindow.lastKeyInput = "Key_Return (Select)"
            } else if (event.key === Qt.Key_Space) {
                testWindow.lastKeyInput = "Key_Space (Action)"
            } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
                testWindow.lastKeyInput = "Key_Esc (Back)"
            }
        }
    }
}
