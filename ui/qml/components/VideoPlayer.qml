import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Item {
    id: playerView
    anchors.fill: parent
    focus: true

    property var item: null
    property bool isPlaying: true
    property real currentPosition: 245
    property real duration: 7200
    property bool osdVisible: true

    signal closeRequested()

    // Black background for native video rendering surface
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // Video Title Overlay (Top Left)
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 120
        visible: osdVisible
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#d9000000" }
            GradientStop { position: 1.0; color: "#00000000" }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 30

            Text {
                text: item ? item.title : "Media Stream"
                font.pixelSize: 26
                font.bold: true
                color: "#ffffff"
            }

            Item { Layout.fillWidth: true }
        }
    }

    // OSD Transport Controls (Bottom)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 160
        visible: osdVisible
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#e6000000" }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 40
            anchors.rightMargin: 40
            anchors.bottomMargin: 20
            spacing: 12

            // Seek Bar Progress
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                Text {
                    text: formatTime(currentPosition)
                    font.pixelSize: 16
                    color: "#ffffff"
                    font.bold: true
                }

                Slider {
                    id: positionSlider
                    Layout.fillWidth: true
                    from: 0
                    to: duration
                    value: currentPosition
                    activeFocusOnTab: true
                    focus: true
                    onMoved: currentPosition = value

                    background: Rectangle {
                        x: positionSlider.leftPadding
                        y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                        implicitWidth: 200
                        implicitHeight: 8
                        width: positionSlider.availableWidth
                        height: implicitHeight
                        radius: 4
                        color: "#40ffffff"

                        Rectangle {
                            width: positionSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#00a4dc"
                            radius: 4
                        }
                    }

                    handle: Rectangle {
                        x: positionSlider.leftPadding + positionSlider.visualPosition * (positionSlider.availableWidth - width)
                        y: positionSlider.topPadding + positionSlider.availableHeight / 2 - height / 2
                        implicitWidth: positionSlider.activeFocus ? 24 : 16
                        implicitHeight: positionSlider.activeFocus ? 24 : 16
                        radius: 12
                        color: positionSlider.activeFocus ? "#00bdff" : "#ffffff"
                        border.color: "#00a4dc"
                        border.width: 2
                    }
                }

                Text {
                    text: formatTime(duration)
                    font.pixelSize: 16
                    color: "#a0a5ba"
                }
            }

            // Transport Control Buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24

                Button {
                    text: "⏮ -10s"
                    onClicked: currentPosition = Math.max(0, currentPosition - 10)
                }

                Button {
                    id: playPauseBtn
                    text: isPlaying ? "⏸ Pause" : "▶ Play"
                    highlighted: true
                    activeFocusOnTab: true
                    onClicked: isPlaying = !isPlaying
                }

                Button {
                    text: "⏭ +10s"
                    onClicked: currentPosition = Math.min(duration, currentPosition + 10)
                }

                Button {
                    text: "✖ Exit"
                    onClicked: playerView.closeRequested()
                }
            }
        }
    }

    // Hide OSD Timer
    Timer {
        id: osdTimer
        interval: 4000
        running: true
        repeat: false
        onTriggered: osdVisible = false
    }

    // Remote D-Pad / Gamepad Controller / Keyboard Input Listeners
    Keys.onPressed: function(event) {
        showOSD()
        var k = event.key
        if (k === Qt.Key_Space || k === Qt.Key_K || k === Qt.Key_MediaPlay || k === Qt.Key_MediaPause || k === Qt.Key_MediaTogglePlayPause || k === Qt.Key_ButtonA || k === Qt.Key_Select || k === Qt.Key_Return || k === Qt.Key_Enter) {
            isPlaying = !isPlaying
            event.accepted = true
        } else if (k === Qt.Key_Left || k === Qt.Key_J || k === Qt.Key_MediaRewind || k === Qt.Key_ButtonL2 || k === Qt.Key_PageUp) {
            currentPosition = Math.max(0, currentPosition - 10)
            event.accepted = true
        } else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_MediaFastForward || k === Qt.Key_ButtonR2 || k === Qt.Key_PageDown) {
            currentPosition = Math.min(duration, currentPosition + 10)
            event.accepted = true
        } else if (k === Qt.Key_MediaNext || k === Qt.Key_ButtonR1 || k === Qt.Key_N) {
            currentPosition = Math.min(duration, currentPosition + 30)
            event.accepted = true
        } else if (k === Qt.Key_MediaPrevious || k === Qt.Key_ButtonL1 || k === Qt.Key_P) {
            currentPosition = 0
            event.accepted = true
        } else if (k === Qt.Key_Escape || k === Qt.Key_Backspace || k === Qt.Key_Back || k === Qt.Key_ButtonB || k === Qt.Key_MediaStop) {
            playerView.closeRequested()
            event.accepted = true
        }
    }

    function showOSD() {
        osdVisible = true
        osdTimer.restart()
    }

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        var h = Math.floor(m / 60)
        m = m % 60
        if (h > 0) {
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
        }
        return m + ":" + (s < 10 ? "0" : "") + s
    }
}
