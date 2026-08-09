import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: musicMiniPlayer
    height: 68
    radius: 14
    color: "#e60b1329"
    border.color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
    border.width: 1
    clip: true

    signal expandRequested()

    property var activeTrack: AppData.currentMusicTrack

    // Top progress line
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 3
        color: "#1e293b"

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * (AppData.musicDuration > 0 ? (AppData.musicPosition / AppData.musicDuration) : 0)
            color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 3
        spacing: 16

        // Album Art Thumbnail
        Rectangle {
            width: 48
            height: 48
            radius: 8
            color: "#1e293b"
            border.color: "#334155"
            border.width: 1
            clip: true

            Image {
                anchors.fill: parent
                source: (musicMiniPlayer.activeTrack && (musicMiniPlayer.activeTrack.posterUrl || musicMiniPlayer.activeTrack.albumPosterUrl)) ? (musicMiniPlayer.activeTrack.posterUrl || musicMiniPlayer.activeTrack.albumPosterUrl) : "../assets/icons/music.svg"
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            // Animated Playing Waves Icon Overlay
            RowLayout {
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 4
                spacing: 2
                visible: AppData.isMusicPlaying

                Rectangle { width: 3; height: 10; color: "#00f0ff"; radius: 1 }
                Rectangle { width: 3; height: 14; color: "#00f0ff"; radius: 1 }
                Rectangle { width: 3; height: 8; color: "#00f0ff"; radius: 1 }
            }
        }

        // Track Info
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: musicMiniPlayer.activeTrack ? musicMiniPlayer.activeTrack.title : "No Track Playing"
                font.pixelSize: 14
                font.bold: true
                color: "#ffffff"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: musicMiniPlayer.activeTrack ? (musicMiniPlayer.activeTrack.artist || musicMiniPlayer.activeTrack.subtitle || musicMiniPlayer.activeTrack.album || "Music") : ""
                font.pixelSize: 12
                color: "#94a3b8"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        // Transport Mini Controls
        RowLayout {
            spacing: 10

            // Play / Pause Button
            Rectangle {
                id: miniPlayBtn
                width: 38
                height: 38
                radius: 19
                color: activeFocus ? AppData.currentTheme.focusCard : "#1e293b"
                border.color: activeFocus ? AppData.currentTheme.accent : "#334155"
                border.width: activeFocus ? 2 : 1
                focus: true

                Text {
                    anchors.centerIn: parent
                    text: AppData.isMusicPlaying ? "⏸" : "▶"
                    font.pixelSize: 16
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppData.toggleMusicPlayPause()
                }

                Keys.onReturnPressed: AppData.toggleMusicPlayPause()
                Keys.onSpacePressed: AppData.toggleMusicPlayPause()
                Keys.onRightPressed: miniNextBtn.forceActiveFocus()
                Keys.onUpPressed: expandBtn.forceActiveFocus()
            }

            // Next Track Button
            Rectangle {
                id: miniNextBtn
                width: 34
                height: 34
                radius: 17
                color: activeFocus ? AppData.currentTheme.focusCard : "#1e293b"
                border.color: activeFocus ? AppData.currentTheme.accent : "#334155"
                border.width: activeFocus ? 2 : 1

                Text {
                    anchors.centerIn: parent
                    text: "⏭"
                    font.pixelSize: 14
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppData.nextMusicTrack()
                }

                Keys.onReturnPressed: AppData.nextMusicTrack()
                Keys.onSpacePressed: AppData.nextMusicTrack()
                Keys.onLeftPressed: miniPlayBtn.forceActiveFocus()
                Keys.onRightPressed: expandBtn.forceActiveFocus()
            }

            // Expand to Full Player Button
            Rectangle {
                id: expandBtn
                width: 38
                height: 38
                radius: 10
                color: activeFocus ? AppData.currentTheme.accent : "#0284c7"
                border.color: activeFocus ? "#ffffff" : "#0284c7"
                border.width: activeFocus ? 2 : 0

                Text {
                    anchors.centerIn: parent
                    text: "⤢"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#ffffff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: musicMiniPlayer.expandRequested()
                }

                Keys.onReturnPressed: musicMiniPlayer.expandRequested()
                Keys.onSpacePressed: musicMiniPlayer.expandRequested()
                Keys.onLeftPressed: miniNextBtn.forceActiveFocus()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: musicMiniPlayer.expandRequested()
    }
}
