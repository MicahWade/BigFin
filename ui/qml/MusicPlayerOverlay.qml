import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.0

Item {
    id: musicPlayerOverlay
    anchors.fill: parent
    focus: true

    property var item: AppData.currentMusicTrack ? AppData.currentMusicTrack : (AppData.selectedMediaItem ? AppData.selectedMediaItem : null)
    property var activeTrack: AppData.currentMusicTrack ? AppData.currentMusicTrack : item

    signal closeRequested()

    // Native Audio Stream Player Engine
    property string streamUrl: {
        if (activeTrack && activeTrack.id && AppData.liveServerUrl && AppData.accessToken) {
            return AppData.liveServerUrl + "/Audio/" + activeTrack.id + "/stream?static=true&api_key=" + AppData.accessToken
        }
        return ""
    }

    MediaPlayer {
        id: audioStreamPlayer
        source: musicPlayerOverlay.streamUrl
        audioOutput: AudioOutput { id: audioOut; volume: 1.0 }

        onPositionChanged: {
            if (audioStreamPlayer.position > 0) {
                AppData.musicPosition = Math.floor(audioStreamPlayer.position / 1000)
            }
        }

        onDurationChanged: {
            if (audioStreamPlayer.duration > 0) {
                AppData.musicDuration = Math.floor(audioStreamPlayer.duration / 1000)
            }
        }

        onPlaybackStateChanged: {
            AppData.isMusicPlaying = (audioStreamPlayer.playbackState === MediaPlayer.PlayingState)
        }

        onMediaStatusChanged: {
            if (audioStreamPlayer.mediaStatus === MediaPlayer.EndOfMedia) {
                AppData.nextMusicTrack()
            }
        }
    }

    Connections {
        target: AppData
        ignoreUnknownSignals: true

        function onIsMusicPlayingChanged() {
            if (AppData.isMusicPlaying) {
                if (audioStreamPlayer.playbackState !== MediaPlayer.PlayingState) {
                    audioStreamPlayer.play()
                }
            } else {
                if (audioStreamPlayer.playbackState === MediaPlayer.PlayingState) {
                    audioStreamPlayer.pause()
                }
            }
        }

        function onMusicTrackChanged(track) {
            if (track) {
                console.log("[MUSIC PLAYER OVERLAY] Track changed: " + track.title)
                if (track.rawData && track.rawData.RunTimeTicks) {
                    AppData.musicDuration = Math.round(track.rawData.RunTimeTicks / 10000000)
                } else if (track.duration) {
                    var parts = track.duration.split(" ")
                    var durSec = 180
                    for (var p = 0; p < parts.length; p++) {
                        if (parts[p].indexOf("m") !== -1) durSec = parseInt(parts[p]) * 60
                        else if (parts[p].indexOf("s") !== -1) durSec += parseInt(parts[p])
                    }
                    AppData.musicDuration = durSec
                } else {
                    AppData.musicDuration = 220
                }
                AppData.musicPosition = 0
                audioStreamPlayer.play()
            }
        }
    }

    Component.onCompleted: {
        AppData.isMusicPlayerActive = true
        if (activeTrack) {
            if (!AppData.currentMusicTrack) {
                AppData.playMusicItem(activeTrack)
            } else {
                audioStreamPlayer.play()
            }
        }
    }

    Component.onDestruction: {
        AppData.isMusicPlayerActive = false
    }

    function exitPlayer() {
        AppData.isMusicPlayerActive = false
        musicPlayerOverlay.closeRequested()
    }

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    // Dynamic Glassmorphic Ambient Background (Blurred Poster Aura)
    Rectangle {
        anchors.fill: parent
        color: "#070a12"
        z: -2

        Image {
            id: bgArt
            anchors.fill: parent
            source: (activeTrack && (activeTrack.posterUrl || activeTrack.albumPosterUrl || activeTrack.backdropUrl)) ? (activeTrack.posterUrl || activeTrack.albumPosterUrl || activeTrack.backdropUrl) : "assets/icons/music.svg"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.25
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f0070a12" }
                GradientStop { position: 0.5; color: "#bf0f172a" }
                GradientStop { position: 1.0; color: "#f0070a12" }
            }
        }
    }

    // Top Navigation Header
    Rectangle {
        id: headerBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: "transparent"
        z: 10

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 36
            anchors.rightMargin: 36

            // Exit / Back Button
            Rectangle {
                id: backBtn
                width: 120
                height: 44
                radius: 22
                color: activeFocus ? AppData.currentTheme.focusCard : "#1e293b"
                border.color: activeFocus ? AppData.currentTheme.accent : "#475569"
                border.width: activeFocus ? 3 : 1
                scale: activeFocus ? 1.05 : 1.0

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        width: 16
                        height: 16
                        source: "assets/icons/arrow_left.svg"
                        fillMode: Image.PreserveAspectFit
                    }
                    Text { text: "Exit"; font.pixelSize: 14; font.bold: true; color: "#ffffff" }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: exitPlayer()
                }

                Keys.onReturnPressed: exitPlayer()
                Keys.onSelectPressed: exitPlayer()
                Keys.onDownPressed: playPauseBtn.forceActiveFocus()
            }

            // Music Title Category Badge
            RowLayout {
                Layout.leftMargin: 20
                spacing: 10

                Text {
                    text: "🎵  NOW PLAYING"
                    font.pixelSize: 14
                    font.bold: true
                    color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
                }

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: "#475569"
                }

                Text {
                    text: activeTrack ? (activeTrack.album || activeTrack.artist || "Music") : "Music Player"
                    font.pixelSize: 14
                    color: "#94a3b8"
                }
            }

            Item { Layout.fillWidth: true }
        }
        }
    }

    // Main Stage Area (Split Layout: Album Cover & Visualizer on Left, Controls & Queue on Right)
    RowLayout {
        anchors.top: headerBar.bottom
        anchors.bottom: seekSection.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 48
        anchors.rightMargin: 48
        anchors.bottomMargin: 10
        spacing: 48

        // ==========================================
        // LEFT STAGE: ARTWORK & EQUALIZER VISUALIZER
        // ==========================================
        ColumnLayout {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 24

            Item { Layout.fillHeight: true }

            // Prominent Album Cover Card with Neon Glow Aura
            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 290
                height: 290

                // Pulsing Background Glow Aura
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -12
                    radius: 24
                    color: "transparent"
                    border.color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
                    border.width: 3
                    opacity: AppData.isMusicPlaying ? 0.7 : 0.2
                    scale: AppData.isMusicPlaying ? 1.04 : 1.0

                    Behavior on scale { NumberAnimation { duration: 800; easing.type: Easing.InOutSine } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }

                // Artwork Card Container
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: "#0f172a"
                    border.color: "#334155"
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: (activeTrack && (activeTrack.posterUrl || activeTrack.albumPosterUrl)) ? (activeTrack.posterUrl || activeTrack.albumPosterUrl) : "assets/icons/music.svg"
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }

                    // Fallback Music Icon if no poster
                    Item {
                        anchors.fill: parent
                        visible: !activeTrack || (!activeTrack.posterUrl && !activeTrack.albumPosterUrl)

                        Image {
                            anchors.centerIn: parent
                            width: 120
                            height: 120
                            source: "assets/icons/music.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                    }
                }
            }

            // Animated Equalizer Visualizer Soundwaves Canvas
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 290
                height: 48
                radius: 12
                color: "#120f172a"
                border.color: "#1e293b"
                border.width: 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: 18

                        Rectangle {
                            id: eqBar
                            width: 8
                            height: AppData.isMusicPlaying ? Math.max(8, (index % 5 === 0 ? 38 : (index % 3 === 0 ? 28 : (index % 2 === 0 ? 18 : 32))) * eqTimer.barScale) : 6
                            radius: 4
                            color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"

                            Behavior on height { NumberAnimation { duration: 150 } }
                        }
                    }
                }

                Timer {
                    id: eqTimer
                    property real barScale: 1.0
                    interval: 200
                    running: AppData.isMusicPlaying
                    repeat: true
                    onTriggered: {
                        barScale = 0.5 + Math.random() * 0.6
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // ==========================================
        // RIGHT STAGE: TRACK METADATA, CONTROLS & QUEUE
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            Item { Layout.fillHeight: true }

            // Track & Artist Typography
            ColumnLayout {
                spacing: 8

                Text {
                    text: activeTrack ? activeTrack.title : "Select Music Track"
                    font.pixelSize: 32
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: activeTrack ? (activeTrack.artist || activeTrack.albumArtist || activeTrack.subtitle || "Unknown Artist") : ""
                    font.pixelSize: 20
                    font.bold: true
                    color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                RowLayout {
                    spacing: 12
                    Layout.topMargin: 4

                    Rectangle {
                        height: 24
                        width: albumText.implicitWidth + 16
                        radius: 6
                        color: "#1e293b"
                        border.color: "#334155"
                        border.width: 1

                        Text {
                            id: albumText
                            anchors.centerIn: parent
                            text: activeTrack ? (activeTrack.album || "Album") : "Album"
                            font.pixelSize: 11
                            font.bold: true
                            color: "#cbd5e1"
                        }
                    }

                    Rectangle {
                        height: 24
                        width: yearText.implicitWidth + 16
                        radius: 6
                        color: "#1e293b"
                        border.color: "#334155"
                        border.width: 1
                        visible: activeTrack && activeTrack.year !== undefined

                        Text {
                            id: yearText
                            anchors.centerIn: parent
                            text: activeTrack ? String(activeTrack.year) : ""
                            font.pixelSize: 11
                            font.bold: true
                            color: "#94a3b8"
                        }
                    }

                    Text {
                        text: "Track " + (AppData.musicQueueIndex + 1) + " of " + (AppData.musicQueue ? AppData.musicQueue.length : 1)
                        font.pixelSize: 12
                        color: "#64748b"
                    }
                }
            }

            // Dedicated Music Transport Controls
            RowLayout {
                spacing: 16
                Layout.topMargin: 10

                // Shuffle Button (🔀)
                Rectangle {
                    id: shuffleBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: AppData.musicShuffle ? (activeFocus ? AppData.currentTheme.focusCard : "#0284c7") : (activeFocus ? AppData.currentTheme.focusCard : "#0f172a")
                    border.color: activeFocus ? AppData.currentTheme.accent : (AppData.musicShuffle ? "#00f0ff" : "#1e293b")
                    border.width: activeFocus ? 3 : 1

                    Text {
                        anchors.centerIn: parent
                        text: "🔀"
                        font.pixelSize: 18
                        color: AppData.musicShuffle ? "#ffffff" : "#94a3b8"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppData.toggleMusicShuffle()
                    }

                    Keys.onReturnPressed: AppData.toggleMusicShuffle()
                    Keys.onSpacePressed: AppData.toggleMusicShuffle()
                    Keys.onRightPressed: prevBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }

                // Previous Track Button (⏮)
                Rectangle {
                    id: prevBtn
                    width: 54
                    height: 54
                    radius: 27
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0f172a"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    scale: activeFocus ? 1.08 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "⏮"
                        font.pixelSize: 22
                        color: "#ffffff"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppData.prevMusicTrack()
                    }

                    Keys.onReturnPressed: AppData.prevMusicTrack()
                    Keys.onSpacePressed: AppData.prevMusicTrack()
                    Keys.onLeftPressed: shuffleBtn.forceActiveFocus()
                    Keys.onRightPressed: playPauseBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }

                // Main Play / Pause Button (▶ / ⏸)
                Rectangle {
                    id: playPauseBtn
                    width: 72
                    height: 72
                    radius: 36
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0284c7"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#00f0ff"
                    border.width: activeFocus ? 5 : 2
                    scale: activeFocus ? 1.12 : 1.0
                    focus: true

                    Text {
                        anchors.centerIn: parent
                        text: AppData.isMusicPlaying ? "⏸" : "▶"
                        font.pixelSize: 30
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
                    Keys.onLeftPressed: prevBtn.forceActiveFocus()
                    Keys.onRightPressed: nextBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }

                // Next Track Button (⏭)
                Rectangle {
                    id: nextBtn
                    width: 54
                    height: 54
                    radius: 27
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0f172a"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    scale: activeFocus ? 1.08 : 1.0

                    Text {
                        anchors.centerIn: parent
                        text: "⏭"
                        font.pixelSize: 22
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
                    Keys.onLeftPressed: playPauseBtn.forceActiveFocus()
                    Keys.onRightPressed: repeatBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }

                // Repeat Mode Button (🔁)
                Rectangle {
                    id: repeatBtn
                    width: 48
                    height: 48
                    radius: 24
                    color: AppData.musicRepeatMode > 0 ? (activeFocus ? AppData.currentTheme.focusCard : "#0284c7") : (activeFocus ? AppData.currentTheme.focusCard : "#0f172a")
                    border.color: activeFocus ? AppData.currentTheme.accent : (AppData.musicRepeatMode > 0 ? "#00f0ff" : "#1e293b")
                    border.width: activeFocus ? 3 : 1

                    Text {
                        anchors.centerIn: parent
                        text: AppData.musicRepeatMode === 2 ? "🔂" : "🔁"
                        font.pixelSize: 18
                        color: AppData.musicRepeatMode > 0 ? "#ffffff" : "#94a3b8"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppData.cycleMusicRepeatMode()
                    }

                    Keys.onReturnPressed: AppData.cycleMusicRepeatMode()
                    Keys.onSpacePressed: AppData.cycleMusicRepeatMode()
                    Keys.onLeftPressed: nextBtn.forceActiveFocus()
                    Keys.onRightPressed: favBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }

                // Favorite Heart Button (❤️)
                Rectangle {
                    id: favBtn
                    width: 44
                    height: 44
                    radius: 22
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0f172a"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 3 : 1

                    Image {
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: "assets/icons/heart.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (activeTrack) AppData.toggleFavorite(activeTrack)
                        }
                    }

                    Keys.onReturnPressed: { if (activeTrack) AppData.toggleFavorite(activeTrack) }
                    Keys.onLeftPressed: repeatBtn.forceActiveFocus()
                    Keys.onUpPressed: backBtn.forceActiveFocus()
                    Keys.onDownPressed: seekTrack.forceActiveFocus()
                }
            }

            // Now Playing Queue List Section
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                Text {
                    text: "NOW PLAYING QUEUE (" + (AppData.musicQueue ? AppData.musicQueue.length : 0) + ")"
                    font.pixelSize: 12
                    font.bold: true
                    color: "#94a3b8"
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "#0b101d"
                    border.color: "#1e293b"
                    border.width: 1
                    clip: true

                    ListView {
                        id: queueListView
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6
                        focus: true
                        model: AppData.musicQueue

                        delegate: Rectangle {
                            width: queueListView.width
                            height: 42
                            radius: 8
                            color: (queueMouse.containsMouse || activeFocus) ? AppData.currentTheme.focusCard : (AppData.musicQueueIndex === index ? "#1e293b" : "transparent")
                            border.color: (queueMouse.containsMouse || activeFocus) ? AppData.currentTheme.accent : "transparent"
                            border.width: (queueMouse.containsMouse || activeFocus) ? 2 : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                Text {
                                    text: AppData.musicQueueIndex === index ? "▶" : String(index + 1)
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: AppData.musicQueueIndex === index ? (AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff") : "#64748b"
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        text: modelData.title
                                        font.pixelSize: 13
                                        font.bold: AppData.musicQueueIndex === index
                                        color: AppData.musicQueueIndex === index ? "#ffffff" : "#cbd5e1"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        text: modelData.artist || modelData.subtitle || ""
                                        font.pixelSize: 10
                                        color: "#64748b"
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                        visible: modelData.artist !== undefined
                                    }
                                }

                                Text {
                                    text: modelData.duration || ""
                                    font.pixelSize: 11
                                    color: "#64748b"
                                }
                            }

                            MouseArea {
                                id: queueMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    AppData.musicQueueIndex = index
                                    AppData.currentMusicTrack = modelData
                                    AppData.isMusicPlaying = true
                                    AppData.musicTrackChanged(modelData)
                                }
                            }

                            Keys.onReturnPressed: {
                                AppData.musicQueueIndex = index
                                AppData.currentMusicTrack = modelData
                                AppData.isMusicPlaying = true
                                AppData.musicTrackChanged(modelData)
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ==========================================
    // BOTTOM SCRUBBER SEEK BAR SECTION
    // ==========================================
    Item {
        id: seekSection
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80

        RowLayout {
            anchors.centerIn: parent
            width: parent.width - 96
            spacing: 16

            Text {
                text: formatTime(AppData.musicPosition)
                font.pixelSize: 14
                font.bold: true
                color: "#ffffff"
            }

            Rectangle {
                id: seekTrack
                Layout.fillWidth: true
                height: 12
                radius: 6
                color: activeFocus ? AppData.currentTheme.focusCard : "#1e293b"
                border.color: activeFocus ? AppData.currentTheme.accent : "transparent"
                border.width: activeFocus ? 2 : 0
                focus: true

                Rectangle {
                    width: seekTrack.width * (AppData.musicDuration > 0 ? (AppData.musicPosition / AppData.musicDuration) : 0)
                    height: parent.height
                    radius: 6
                    color: AppData.currentTheme.accent ? AppData.currentTheme.accent : "#00f0ff"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        var ratio = Math.max(0, Math.min(1.0, mouse.x / seekTrack.width))
                        AppData.musicPosition = ratio * AppData.musicDuration
                        audioStreamPlayer.setPosition(AppData.musicPosition * 1000)
                    }
                }

                Keys.onLeftPressed: {
                    AppData.musicPosition = Math.max(0, AppData.musicPosition - 10)
                    audioStreamPlayer.setPosition(AppData.musicPosition * 1000)
                }
                Keys.onRightPressed: {
                    AppData.musicPosition = Math.min(AppData.musicDuration, AppData.musicPosition + 10)
                    audioStreamPlayer.setPosition(AppData.musicPosition * 1000)
                }
                Keys.onUpPressed: playPauseBtn.forceActiveFocus()
            }

            Text {
                text: formatTime(AppData.musicDuration)
                font.pixelSize: 14
                font.bold: true
                color: "#94a3b8"
            }
        }
    }

    // Keyboard & D-Pad Remote Input Handler
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_K || event.key === Qt.Key_MediaPlay || event.key === Qt.Key_MediaPause || event.key === Qt.Key_MediaTogglePlayPause) {
            AppData.toggleMusicPlayPause()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            exitPlayer()
            event.accepted = true
        } else if (event.key === Qt.Key_J || event.key === Qt.Key_PageUp) {
            AppData.prevMusicTrack()
            event.accepted = true
        } else if (event.key === Qt.Key_L || event.key === Qt.Key_PageDown) {
            AppData.nextMusicTrack()
            event.accepted = true
        } else if (event.key === Qt.Key_S) {
            AppData.toggleMusicShuffle()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            AppData.cycleMusicRepeatMode()
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            audioOut.muted = !audioOut.muted
            event.accepted = true
        }
    }
}
