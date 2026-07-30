import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: sessionModal
    anchors.fill: parent
    color: "#e6080c14"
    z: 250

    signal sessionSwitched(var session)
    signal addAccountRequested()
    signal closeRequested()

    property var sessionsList: AppData.savedSessions
    property string activeSessionId: AppData.activeSessionId

    Rectangle {
        id: card
        width: Math.min(720, parent.width - 64)
        height: Math.min(580, parent.height - 64)
        anchors.centerIn: parent
        radius: 16
        color: AppData.currentTheme.cardBg
        border.color: AppData.currentTheme.accent
        border.width: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    width: 48
                    height: 48
                    radius: 12
                    color: "#0f172a"
                    border.color: AppData.currentTheme.accent
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        source: "assets/Logo.png"
                        fillMode: Image.PreserveAspectFit
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "Jellyfin Sessions & Accounts"
                        font.pixelSize: 22
                        font.bold: true
                        color: "#ffffff"
                    }
                    Text {
                        text: "Select a saved user session or add a new Jellyfin server connection"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: closeBtn
                    width: 36
                    height: 36
                    radius: 18
                    color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.color: activeFocus ? "#ffffff" : "#475569"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 14
                        font.bold: true
                        color: closeBtn.activeFocus ? "#0f172a" : "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: sessionModal.closeRequested()
                    }

                    Keys.onReturnPressed: sessionModal.closeRequested()
                    Keys.onSpacePressed: sessionModal.closeRequested()
                }
            }

            // Sessions List View
            ListView {
                id: sessionsListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 12
                focus: true

                model: AppData.savedSessions

                onActiveFocusChanged: {
                    if (activeFocus && currentItem) {
                        currentItem.forceActiveFocus()
                    }
                }

                delegate: Item {
                    id: sessionDelegate
                    width: sessionsListView.width
                    height: 84
                    focus: true

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            sessionRowCard.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        id: sessionRowCard
                        anchors.fill: parent
                        radius: 12
                        color: activeFocus ? AppData.currentTheme.focusCard : (modelData.id === AppData.activeSessionId ? "#0f172a" : "#090d16")
                        border.color: activeFocus ? AppData.currentTheme.accent : (modelData.id === AppData.activeSessionId ? "#0284c7" : "#1e293b")
                        border.width: activeFocus ? 3 : (modelData.id === AppData.activeSessionId ? 2 : 1)
                        focus: true

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 20
                            anchors.rightMargin: 20
                            spacing: 16

                            // User Avatar / Icon
                            Rectangle {
                                width: 44
                                height: 44
                                radius: 22
                                color: "#1e293b"
                                border.color: AppData.currentTheme.accent
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.username ? modelData.username.substring(0, 1).toUpperCase() : "U")
                                    font.pixelSize: 18
                                    font.bold: true
                                    color: AppData.currentTheme.accent
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: modelData.username || "User"
                                        font.pixelSize: 17
                                        font.bold: true
                                        color: "#ffffff"
                                    }

                                    Rectangle {
                                        visible: modelData.id === AppData.activeSessionId
                                        height: 20
                                        width: 60
                                        radius: 4
                                        color: "#22c55e"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "ACTIVE"
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                    }
                                }

                                Text {
                                    text: (modelData.serverName || "Jellyfin") + "  •  " + (modelData.serverUrl || "")
                                    font.pixelSize: 12
                                    color: "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            // Switch Action Button
                            Rectangle {
                                id: switchBtn
                                width: 100
                                height: 40
                                radius: 8
                                color: (switchMouse.containsMouse || switchBtn.activeFocus) ? AppData.currentTheme.accent : "#0284c7"
                                border.color: "#ffffff"
                                border.width: switchBtn.activeFocus ? 2 : 0

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.id === AppData.activeSessionId ? "Selected" : "Switch"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: switchMouse
                                    anchors.fill: parent
                                    onClicked: {
                                        AppData.switchToSession(modelData.id)
                                        sessionModal.sessionSwitched(modelData)
                                    }
                                }

                                Keys.onReturnPressed: {
                                    AppData.switchToSession(modelData.id)
                                    sessionModal.sessionSwitched(modelData)
                                }
                                Keys.onSpacePressed: {
                                    AppData.switchToSession(modelData.id)
                                    sessionModal.sessionSwitched(modelData)
                                }
                            }

                            // Delete Session Button
                            Rectangle {
                                id: deleteBtn
                                width: 36
                                height: 36
                                radius: 8
                                color: (deleteMouse.containsMouse || deleteBtn.activeFocus) ? "#ef4444" : "#1e293b"

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗑"
                                    font.pixelSize: 14
                                    color: "#ffffff"
                                }

                                MouseArea {
                                    id: deleteMouse
                                    anchors.fill: parent
                                    onClicked: AppData.deleteSession(modelData.id)
                                }

                                Keys.onReturnPressed: AppData.deleteSession(modelData.id)
                                Keys.onSpacePressed: AppData.deleteSession(modelData.id)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                sessionsListView.currentIndex = index
                                sessionRowCard.forceActiveFocus()
                                AppData.switchToSession(modelData.id)
                                sessionModal.sessionSwitched(modelData)
                            }
                        }

                        Keys.onReturnPressed: {
                            AppData.switchToSession(modelData.id)
                            sessionModal.sessionSwitched(modelData)
                        }
                        Keys.onSpacePressed: {
                            AppData.switchToSession(modelData.id)
                            sessionModal.sessionSwitched(modelData)
                        }

                        Keys.onUpPressed: function(event) {
                            if (index === 0) {
                                addAccountBtn.forceActiveFocus()
                            } else {
                                sessionsListView.decrementCurrentIndex()
                                if (sessionsListView.currentItem) sessionsListView.currentItem.forceActiveFocus()
                            }
                            event.accepted = true
                        }

                        Keys.onDownPressed: function(event) {
                            if (index < sessionsListView.count - 1) {
                                sessionsListView.incrementCurrentIndex()
                                if (sessionsListView.currentItem) sessionsListView.currentItem.forceActiveFocus()
                            }
                            event.accepted = true
                        }
                    }
                }
            }

            // Bottom Add Account Button
            Rectangle {
                id: addAccountBtn
                Layout.fillWidth: true
                height: 52
                radius: 10
                focus: true
                color: (addMouse.containsMouse || activeFocus) ? AppData.currentTheme.accent : "#0f172a"
                border.color: (addMouse.containsMouse || activeFocus) ? "#ffffff" : AppData.currentTheme.accent
                border.width: (addMouse.containsMouse || activeFocus) ? 3 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Text {
                        text: "➕"
                        font.pixelSize: 16
                    }

                    Text {
                        text: "Add New Jellyfin Account / Server"
                        font.pixelSize: 16
                        font.bold: true
                        color: (addMouse.containsMouse || addAccountBtn.activeFocus) ? "#0f172a" : "#ffffff"
                    }
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addAccountBtn.forceActiveFocus()
                        sessionModal.addAccountRequested()
                    }
                }

                Keys.onReturnPressed: sessionModal.addAccountRequested()
                Keys.onSpacePressed: sessionModal.addAccountRequested()
                Keys.onDownPressed: function(event) {
                    if (sessionsListView.count > 0) {
                        sessionsListView.forceActiveFocus()
                    }
                    event.accepted = true
                }
            }
        }
    }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace) {
            sessionModal.closeRequested()
            event.accepted = true
        }
    }
}
