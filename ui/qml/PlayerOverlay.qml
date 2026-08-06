import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtMultimedia 6.0

Item {
    id: playerOverlay
    anchors.fill: parent
    focus: true

    property var item: null
    property bool isPlaying: true
    property real currentPosition: 0.0 // seconds
    property real totalDuration: 1440.0 // seconds (24 mins)
    property string activeAudioTrack: "English (AAC 5.1)"
    property string activeSubtitleTrack: "Off"

    signal closeRequested()

    property var activeMedia: item ? item : AppData.featuredHero

    property string streamUrl: {
        if (activeMedia && activeMedia.id && AppData.liveServerUrl && AppData.accessToken) {
            var mType = activeMedia.mediaType || activeMedia.Type || (activeMedia.rawData ? activeMedia.rawData.Type : "")
            var isAudio = (mType === "Audio" || mType === "MusicTrack" || mType === "MusicAlbum" || mType === "Playlist")
            if (isAudio) {
                return AppData.liveServerUrl + "/Audio/" + activeMedia.id + "/stream?static=true&api_key=" + AppData.accessToken
            }
            var msId = (activeMedia.rawData && activeMedia.rawData.MediaSources && activeMedia.rawData.MediaSources.length > 0) ? activeMedia.rawData.MediaSources[0].Id : activeMedia.id
            return AppData.liveServerUrl + "/Videos/" + activeMedia.id + "/master.m3u8?MediaSourceId=" + msId + "&VideoCodec=h264&AudioCodec=aac,mp3&api_key=" + AppData.accessToken
        }
        return ""
    }

    // Fullscreen Pitch Black Canvas (renders seamless pitch-black letterbox & pillarbox bars)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        z: -1
    }

    // Native Hardware-Accelerated Video Player
    MediaPlayer {
        id: mediaStreamPlayer
        source: playerOverlay.streamUrl
        videoOutput: videoOutput
        audioOutput: AudioOutput { id: audioOut; volume: 1.0 }

        onPositionChanged: {
            if (mediaStreamPlayer.position > 0) {
                playerOverlay.currentPosition = Math.floor(mediaStreamPlayer.position / 1000)
            }
        }

        onDurationChanged: {
            if (mediaStreamPlayer.duration > 0) {
                playerOverlay.totalDuration = Math.floor(mediaStreamPlayer.duration / 1000)
            }
        }

        onPlaybackStateChanged: {
            playerOverlay.isPlaying = (mediaStreamPlayer.playbackState === MediaPlayer.PlayingState)
        }

        onMediaStatusChanged: {
            if (mediaStreamPlayer.mediaStatus === MediaPlayer.EndOfMedia) {
                if (activeMedia && activeMedia.id) {
                    AppData.reportPlaybackStopped(activeMedia.id, totalDuration)
                    AppData.fetchContinueWatching()
                }
            }
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            mediaStreamPlayer.play()
            if (activeMedia && activeMedia.id) {
                AppData.reportPlaybackProgress(activeMedia.id, currentPosition, false, "unpause")
            }
        } else {
            mediaStreamPlayer.pause()
            if (activeMedia && activeMedia.id) {
                AppData.reportPlaybackProgress(activeMedia.id, currentPosition, true, "pause")
            }
        }
    }

    onActiveMediaChanged: {
        if (activeMedia && activeMedia.rawData && activeMedia.rawData.RunTimeTicks) {
            totalDuration = Math.round(activeMedia.rawData.RunTimeTicks / 10000000)
        } else {
            totalDuration = 1440.0
        }

        if (activeMedia && activeMedia.id) {
            console.log("[VIDEO PLAYER] Streaming video URL: " + streamUrl)
            mediaStreamPlayer.play()
            AppData.reportPlaybackStart(activeMedia.id, currentPosition)

            // Auto-enter fullscreen mode when show is added/played if not Plasma Bigscreen
            var isBigscreen = (typeof isPlasmaBigscreenEnv !== "undefined") ? isPlasmaBigscreenEnv : false
            if (!isBigscreen && typeof rootWindow !== "undefined" && rootWindow) {
                console.log("[PLAYER] Desktop environment detected: Auto entering Fullscreen mode")
                rootWindow.showFullScreen()
            }
        }

        if (activeMedia && activeMedia.rawData && activeMedia.rawData.UserData && activeMedia.rawData.UserData.PlaybackPositionTicks > 0) {
            currentPosition = Math.floor(activeMedia.rawData.UserData.PlaybackPositionTicks / 10000000)
            mediaStreamPlayer.setPosition(currentPosition * 1000)
            console.log("[PLAYER] Resuming playback at " + currentPosition + " seconds (" + formatTime(currentPosition) + " / " + formatTime(totalDuration) + ")")
        } else {
            currentPosition = 0
        }
    }

    function exitPlayer() {
        mediaStreamPlayer.stop()
        if (activeMedia && activeMedia.id) {
            AppData.reportPlaybackStopped(activeMedia.id, currentPosition)
            AppData.fetchContinueWatching()
        }
        var isBigscreen = (typeof isPlasmaBigscreenEnv !== "undefined") ? isPlasmaBigscreenEnv : false
        if (!isBigscreen && typeof rootWindow !== "undefined" && rootWindow) {
            rootWindow.showNormal()
        }
        playerOverlay.closeRequested()
    }

    property alias defaultFocusItem: playPauseBtn

    // Auto-Hide Inactivity Timer (4 seconds)
    Timer {
        id: autoHideTimer
        interval: 4000
        running: true
        repeat: false
        onTriggered: {
            controlsContainer.visibleControls = false
        }
    }

    function wakeControls() {
        controlsContainer.visibleControls = true
        autoHideTimer.restart()
    }

    property bool isBuffering: mediaStreamPlayer.mediaStatus === MediaPlayer.Buffering || 
                               mediaStreamPlayer.mediaStatus === MediaPlayer.StalledMedia || 
                               mediaStreamPlayer.mediaStatus === MediaPlayer.LoadingMedia

    // Video Output surface (renders video with PreserveAspectFit inside black bar canvas)
    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }

    // Ambient Fallback Poster (shown only when media player is stopped or has no media loaded)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        visible: mediaStreamPlayer.playbackState === MediaPlayer.StoppedState || mediaStreamPlayer.mediaStatus === MediaPlayer.NoMedia

        Image {
            anchors.fill: parent
            source: activeMedia.backdropUrl ? activeMedia.backdropUrl : activeMedia.posterUrl
            fillMode: Image.PreserveAspectCrop
            opacity: 0.7
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#aa000000" }
                GradientStop { position: 0.4; color: "#22000000" }
                GradientStop { position: 1.0; color: "#dd000000" }
            }
        }
    }

    // Buffering Indicator Overlay (Centered HUD)
    Rectangle {
        id: bufferingOverlay
        anchors.centerIn: parent
        width: 190
        height: 110
        radius: 16
        color: "#d90f172a"
        border.color: "#00f0ff"
        border.width: 1
        visible: playerOverlay.isBuffering && mediaStreamPlayer.playbackState !== MediaPlayer.StoppedState
        z: 80

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12

            Item {
                Layout.alignment: Qt.AlignHCenter
                width: 44
                height: 44

                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: "transparent"
                    border.color: "#3300f0ff"
                    border.width: 4
                }

                Rectangle {
                    id: spinnerArc
                    anchors.fill: parent
                    radius: 22
                    color: "transparent"
                    border.color: "#00f0ff"
                    border.width: 4
                    clip: true

                    Rectangle {
                        width: parent.width / 2
                        height: parent.height / 2
                        color: "#0f172a"
                    }

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: bufferingOverlay.visible
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: (mediaStreamPlayer.bufferProgress > 0 && mediaStreamPlayer.bufferProgress < 1.0) ? ("BUFFERING " + Math.round(mediaStreamPlayer.bufferProgress * 100) + "%") : "BUFFERING..."
                font.pixelSize: 12
                font.bold: true
                color: "#ffffff"
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: wakeControls()
        onClicked: wakeControls()
    }

    // Sync Playback Progress to Jellyfin Server
    Timer {
        interval: 5000
        running: isPlaying && activeMedia && activeMedia.id
        repeat: true
        onTriggered: {
            if (activeMedia && activeMedia.id) {
                AppData.reportPlaybackProgress(activeMedia.id, currentPosition, false, "timeupdate")
            }
        }
    }

    function formatTime(seconds) {
        var m = Math.floor(seconds / 60)
        var s = Math.floor(seconds % 60)
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    // ==========================================
    // CONTROLS CONTAINER
    // ==========================================
    Item {
        id: controlsContainer
        anchors.fill: parent
        property bool visibleControls: true
        opacity: visibleControls ? 1.0 : 0.0

        Behavior on opacity { NumberAnimation { duration: 300 } }

        // Top Navigation Header
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 90
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#f0000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 36
                anchors.rightMargin: 36

                Rectangle {
                    id: playerBackBtn
                    width: 110
                    height: 44
                    radius: 22
                    color: activeFocus ? "#0284c7" : "#1e293b"
                    border.color: activeFocus ? "#00f0ff" : "#475569"
                    border.width: activeFocus ? 4 : 1
                    scale: activeFocus ? 1.08 : 1.0

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
                        onClicked: playerOverlay.exitPlayer()
                    }

                    Keys.onReturnPressed: playerOverlay.exitPlayer()
                    Keys.onSelectPressed: playerOverlay.exitPlayer()
                    Keys.onDownPressed: playPauseBtn.forceActiveFocus()
                    Keys.onRightPressed: windowMinimizeBtn.forceActiveFocus()
                }

                ColumnLayout {
                    Layout.leftMargin: 16
                    spacing: 2
                    Text {
                        text: activeMedia.title
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ffffff"
                    }
                    Text {
                        text: activeMedia.subtitle ? activeMedia.subtitle : activeMedia.year
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                Item { Layout.fillWidth: true }

                // Desktop Window Controls (Minimize & Toggle Fullscreen)
                RowLayout {
                    spacing: 10

                    // Minimize Window Button
                    Rectangle {
                        id: windowMinimizeBtn
                        height: 36
                        width: 105
                        radius: 18
                        color: activeFocus ? "#0284c7" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "#475569"
                        border.width: activeFocus ? 3 : 1
                        scale: activeFocus ? 1.08 : 1.0

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "🗕"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: "Minimize"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                if (typeof rootWindow !== "undefined" && rootWindow) {
                                    rootWindow.showMinimized()
                                }
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            if (typeof rootWindow !== "undefined" && rootWindow) {
                                rootWindow.showMinimized()
                            }
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            if (typeof rootWindow !== "undefined" && rootWindow) {
                                rootWindow.showMinimized()
                            }
                        }
                        Keys.onLeftPressed: playerBackBtn.forceActiveFocus()
                        Keys.onRightPressed: windowToggleFSBtn.forceActiveFocus()
                        Keys.onDownPressed: playPauseBtn.forceActiveFocus()
                    }

                    // Toggle Fullscreen / Windowed Button
                    Rectangle {
                        id: windowToggleFSBtn
                        height: 36
                        width: 115
                        radius: 18
                        color: activeFocus ? "#0284c7" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "#475569"
                        border.width: activeFocus ? 3 : 1
                        scale: activeFocus ? 1.08 : 1.0

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: (typeof rootWindow !== "undefined" && rootWindow && rootWindow.visibility === 5) ? "🗗" : "🗖"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: (typeof rootWindow !== "undefined" && rootWindow && rootWindow.visibility === 5) ? "Windowed" : "Fullscreen"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                if (typeof rootWindow !== "undefined" && rootWindow) {
                                    if (rootWindow.visibility === 5) {
                                        rootWindow.showNormal()
                                    } else {
                                        rootWindow.showFullScreen()
                                    }
                                }
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            if (typeof rootWindow !== "undefined" && rootWindow) {
                                if (rootWindow.visibility === 5) {
                                    rootWindow.showNormal()
                                } else {
                                    rootWindow.showFullScreen()
                                }
                            }
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            if (typeof rootWindow !== "undefined" && rootWindow) {
                                if (rootWindow.visibility === 5) {
                                    rootWindow.showNormal()
                                } else {
                                    rootWindow.showFullScreen()
                                }
                            }
                        }
                        Keys.onLeftPressed: windowMinimizeBtn.forceActiveFocus()
                        Keys.onDownPressed: playPauseBtn.forceActiveFocus()
                    }
                }
            }
        }

        // Bottom Controls HUD Bar
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 180
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#f0000000" }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 48
                anchors.rightMargin: 48
                anchors.bottomMargin: 24
                spacing: 14

                // Seek Bar Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: formatTime(currentPosition)
                        font.pixelSize: 14
                        font.bold: true
                        color: "#ffffff"
                    }

                    Rectangle {
                        id: seekTrack
                        Layout.fillWidth: true
                        height: 12
                        radius: 6
                        color: activeFocus ? "#0f172a" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "transparent"
                        border.width: activeFocus ? 2 : 0
                        focus: true

                        // Buffer Progress Bar (Subtle loaded buffer bar behind playback position)
                        Rectangle {
                            width: seekTrack.width * Math.max(0, Math.min(1.0, mediaStreamPlayer.bufferProgress > 0 ? mediaStreamPlayer.bufferProgress : (totalDuration > 0 ? (currentPosition / totalDuration) : 0)))
                            height: parent.height
                            radius: 6
                            color: "#4000f0ff"
                        }

                        // Current Playback Position Bar
                        Rectangle {
                            width: seekTrack.width * (totalDuration > 0 ? (currentPosition / totalDuration) : 0)
                            height: parent.height
                            radius: 6
                            color: "#00f0ff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                wakeControls()
                                var ratio = Math.max(0, Math.min(1.0, mouse.x / seekTrack.width))
                                currentPosition = ratio * totalDuration
                                mediaStreamPlayer.setPosition(currentPosition * 1000)
                            }
                        }

                        Keys.onLeftPressed: {
                            wakeControls()
                            currentPosition = Math.max(0, currentPosition - 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onRightPressed: {
                            wakeControls()
                            currentPosition = Math.min(totalDuration, currentPosition + 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onDownPressed: playPauseBtn.forceActiveFocus()
                        Keys.onUpPressed: playerBackBtn.forceActiveFocus()
                    }

                    Text {
                        text: formatTime(totalDuration)
                        font.pixelSize: 14
                        font.bold: true
                        color: "#94a3b8"
                    }
                }

                // Control Buttons Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20

                    Item { Layout.fillWidth: true }

                    // Seek -10s Button
                    Rectangle {
                        id: rewindBtn
                        width: 52
                        height: 52
                        radius: 26
                        color: activeFocus ? "#0284c7" : "#0f172a"
                        border.color: activeFocus ? "#00f0ff" : "#1e293b"
                        border.width: activeFocus ? 4 : 1
                        scale: activeFocus ? 1.12 : 1.0

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: "assets/icons/rewind.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                currentPosition = Math.max(0, currentPosition - 10)
                                mediaStreamPlayer.setPosition(currentPosition * 1000)
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            currentPosition = Math.max(0, currentPosition - 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            currentPosition = Math.max(0, currentPosition - 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onLeftPressed: playerBackBtn.forceActiveFocus()
                        Keys.onRightPressed: playPauseBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    // Play / Pause Toggle Button
                    Rectangle {
                        id: playPauseBtn
                        width: 64
                        height: 64
                        radius: 32
                        color: activeFocus ? "#0284c7" : "#0f172a"
                        border.color: activeFocus ? "#00f0ff" : "#0284c7"
                        border.width: activeFocus ? 5 : 2
                        scale: activeFocus ? 1.15 : 1.0
                        focus: true

                        Behavior on scale { NumberAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Image {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            source: isPlaying ? "assets/icons/pause.svg" : "assets/icons/play.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                isPlaying = !isPlaying
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            isPlaying = !isPlaying
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            isPlaying = !isPlaying
                        }
                        Keys.onSpacePressed: {
                            wakeControls()
                            isPlaying = !isPlaying
                        }
                        Keys.onLeftPressed: rewindBtn.forceActiveFocus()
                        Keys.onRightPressed: forwardBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    // Seek +10s Button
                    Rectangle {
                        id: forwardBtn
                        width: 52
                        height: 52
                        radius: 26
                        color: activeFocus ? "#0284c7" : "#0f172a"
                        border.color: activeFocus ? "#00f0ff" : "#1e293b"
                        border.width: activeFocus ? 4 : 1
                        scale: activeFocus ? 1.12 : 1.0

                        Image {
                            anchors.centerIn: parent
                            width: 22
                            height: 22
                            source: "assets/icons/forward.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                currentPosition = Math.min(totalDuration, currentPosition + 10)
                                mediaStreamPlayer.setPosition(currentPosition * 1000)
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            currentPosition = Math.min(totalDuration, currentPosition + 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            currentPosition = Math.min(totalDuration, currentPosition + 10)
                            mediaStreamPlayer.setPosition(currentPosition * 1000)
                        }
                        Keys.onLeftPressed: playPauseBtn.forceActiveFocus()
                        Keys.onRightPressed: audioBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    Item { Layout.fillWidth: true }

                    // Audio Track Toggle Button
                    Rectangle {
                        id: audioBtn
                        height: 40
                        width: 140
                        radius: 20
                        color: activeFocus ? "#0284c7" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "#475569"
                        border.width: activeFocus ? 4 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "🔊 " + activeAudioTrack
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                activeAudioTrack = (activeAudioTrack.indexOf("5.1") !== -1 ? "English (Stereo)" : "English (AAC 5.1)")
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            activeAudioTrack = (activeAudioTrack.indexOf("5.1") !== -1 ? "English (Stereo)" : "English (AAC 5.1)")
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            activeAudioTrack = (activeAudioTrack.indexOf("5.1") !== -1 ? "English (Stereo)" : "English (AAC 5.1)")
                        }
                        Keys.onLeftPressed: forwardBtn.forceActiveFocus()
                        Keys.onRightPressed: subBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    // Subtitle Track Toggle Button
                    Rectangle {
                        id: subBtn
                        height: 40
                        width: 130
                        radius: 20
                        color: activeFocus ? "#0284c7" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "#475569"
                        border.width: activeFocus ? 4 : 1

                        Text {
                            anchors.centerIn: parent
                            text: "💬 " + activeSubtitleTrack
                            font.pixelSize: 11
                            font.bold: true
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                wakeControls()
                                activeSubtitleTrack = (activeSubtitleTrack.indexOf("SDH") !== -1 ? "Off" : "English [SDH]")
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            activeSubtitleTrack = (activeSubtitleTrack.indexOf("SDH") !== -1 ? "Off" : "English [SDH]")
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            activeSubtitleTrack = (activeSubtitleTrack.indexOf("SDH") !== -1 ? "Off" : "English [SDH]")
                        }
                        Keys.onLeftPressed: audioBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }
                }
            }
        }
    }

    Keys.onPressed: function(event) {
        wakeControls()
        if (event.key === Qt.Key_Space || event.key === Qt.Key_K || event.key === Qt.Key_MediaPlay || event.key === Qt.Key_MediaPause || event.key === Qt.Key_MediaTogglePlayPause) {
            isPlaying = !isPlaying
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            playerOverlay.exitPlayer()
            event.accepted = true
        } else if (event.key === Qt.Key_J) {
            currentPosition = Math.max(0, currentPosition - 10)
            mediaStreamPlayer.setPosition(currentPosition * 1000)
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            currentPosition = Math.min(totalDuration, currentPosition + 10)
            mediaStreamPlayer.setPosition(currentPosition * 1000)
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            audioOut.muted = !audioOut.muted
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            controlsContainer.visibleControls = !controlsContainer.visibleControls
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            if (!playPauseBtn.activeFocus && !rewindBtn.activeFocus && !forwardBtn.activeFocus && !seekTrack.activeFocus && !playerBackBtn.activeFocus && !audioBtn.activeFocus && !subBtn.activeFocus && !windowMinimizeBtn.activeFocus && !windowToggleFSBtn.activeFocus) {
                playPauseBtn.forceActiveFocus()
            }
        }
    }
}
