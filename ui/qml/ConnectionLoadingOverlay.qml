import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: loadingOverlay
    anchors.fill: parent
    z: 500

    property string statusText: "Connecting to Jellyfin Server..."
    property string serverUrl: AppData.liveServerUrl ? AppData.liveServerUrl : ""
    property bool isConnecting: true
    property bool hasError: false
    property string errorMessage: ""

    signal connectionComplete()
    signal openConnectModalRequested()

    // Deep Dark Theme Background with Ambient Radial Glow
    Rectangle {
        anchors.fill: parent
        color: "#070a12"

        Rectangle {
            anchors.centerIn: parent
            width: 600
            height: 600
            radius: 300
            color: hasError ? "#ef4444" : (AppData.currentTheme ? AppData.currentTheme.accent : "#0284c7")
            opacity: 0.08
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 24

        // App Logo Icon
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 90
            height: 90
            radius: 24
            color: "#0f172a"
            border.color: hasError ? "#ef4444" : (AppData.currentTheme ? AppData.currentTheme.accent : "#38bdf8")
            border.width: 2

            Image {
                anchors.centerIn: parent
                width: 60
                height: 60
                source: "assets/Logo.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        // App Title
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Bigfin"
            font.pixelSize: 36
            font.bold: true
            color: "#ffffff"
        }

        // Animated Spinner Ring (Visible while connecting)
        Item {
            Layout.alignment: Qt.AlignHCenter
            width: 56
            height: 56
            visible: isConnecting && !hasError

            Rectangle {
                anchors.fill: parent
                radius: 28
                color: "transparent"
                border.color: "#1e293b"
                border.width: 4
            }

            Rectangle {
                id: spinnerSegment
                anchors.fill: parent
                radius: 28
                color: "transparent"
                border.color: AppData.currentTheme ? AppData.currentTheme.accent : "#00f0ff"
                border.width: 4

                RotationAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                    running: loadingOverlay.isConnecting && !loadingOverlay.hasError
                }
            }
        }

        // Error Badge (Visible on Connection Failure)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 56
            height: 56
            radius: 28
            color: "#3f1212"
            border.color: "#ef4444"
            border.width: 2
            visible: hasError

            Text {
                anchors.centerIn: parent
                text: "!"
                font.pixelSize: 32
                font.bold: true
                color: "#ef4444"
            }
        }

        // Dynamic Connection Status & Error Text
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Text {
                id: statusLabel
                Layout.alignment: Qt.AlignHCenter
                text: hasError ? "Connection Failed" : loadingOverlay.statusText
                font.pixelSize: 18
                font.bold: true
                color: hasError ? "#ef4444" : "#e2e8f0"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: hasError ? errorMessage : (loadingOverlay.serverUrl ? loadingOverlay.serverUrl : "Searching saved sessions...")
                font.pixelSize: 14
                color: hasError ? "#f87171" : "#64748b"
                horizontalAlignment: Text.AlignHCenter
                Layout.maximumWidth: 600
                wrapMode: Text.WordWrap
            }
        }

        // Action Buttons on Connection Failure
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16
            visible: hasError

            Rectangle {
                id: retryBtn
                width: 180
                height: 48
                radius: 10
                focus: hasError
                color: (retryMouse.containsMouse || activeFocus) ? AppData.currentTheme.accent : "#1e293b"
                border.color: (retryMouse.containsMouse || activeFocus) ? "#ffffff" : "#334155"
                border.width: (retryMouse.containsMouse || activeFocus) ? 2 : 1

                Text {
                    anchors.centerIn: parent
                    text: "Retry Connection"
                    font.pixelSize: 14
                    font.bold: true
                    color: (retryMouse.containsMouse || retryBtn.activeFocus) ? "#0f172a" : "#ffffff"
                }

                MouseArea {
                    id: retryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: startConnectionCheck()
                }

                Keys.onReturnPressed: startConnectionCheck()
                Keys.onSpacePressed: startConnectionCheck()
            }

            Rectangle {
                id: configBtn
                width: 200
                height: 48
                radius: 10
                color: (configMouse.containsMouse || activeFocus) ? "#38bdf8" : "#0f172a"
                border.color: (configMouse.containsMouse || activeFocus) ? "#ffffff" : "#0284c7"
                border.width: (configMouse.containsMouse || activeFocus) ? 2 : 1

                Text {
                    anchors.centerIn: parent
                    text: "Connect to Server"
                    font.pixelSize: 14
                    font.bold: true
                    color: (configMouse.containsMouse || configBtn.activeFocus) ? "#0f172a" : "#ffffff"
                }

                MouseArea {
                    id: configMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        loadingOverlay.openConnectModalRequested()
                    }
                }

                Keys.onReturnPressed: loadingOverlay.openConnectModalRequested()
                Keys.onSpacePressed: loadingOverlay.openConnectModalRequested()
            }
        }
    }

    Component.onCompleted: {
        startConnectionCheck()
    }

    Connections {
        target: AppData
        ignoreUnknownSignals: true

        function onConnectionStatusChanged() {
            checkState()
        }

        function onConnectionFailed(msg) {
            hasError = true
            isConnecting = false
            errorMessage = msg
        }
    }

    function checkState() {
        if (AppData.isConnectedToLiveServer) {
            hasError = false
            isConnecting = false
            statusText = "Connected to " + (AppData.serverName || "Jellyfin Server") + "!"
            fadeAnim.start()
        } else if (AppData.connectionError) {
            hasError = true
            isConnecting = false
            errorMessage = AppData.connectionError
        }
    }

    function startConnectionCheck() {
        hasError = false
        isConnecting = true
        statusText = "Connecting to Jellyfin Server..."
        errorMessage = ""
        AppData.loadSavedSessions()
        
        checkTimer.restart()
    }

    Timer {
        id: checkTimer
        interval: 200
        running: false
        repeat: false
        onTriggered: checkState()
    }

    NumberAnimation {
        id: fadeAnim
        target: loadingOverlay
        property: "opacity"
        to: 0.0
        duration: 350
        onStopped: {
            loadingOverlay.visible = false
            loadingOverlay.connectionComplete()
        }
    }
}
