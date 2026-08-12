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
    property bool isScrubbing: false
    property bool pendingInitialSeek: false
    property real targetResumePosition: 0.0

    signal closeRequested()

    property var activeMedia: item ? item : (typeof mainShell !== "undefined" && mainShell && mainShell.selectedMediaItem ? mainShell.selectedMediaItem : AppData.featuredHero)

    readonly property bool isEpisode: {
        if (!activeMedia) return false
        var mType = activeMedia.mediaType || (activeMedia.rawData ? activeMedia.rawData.Type : "")
        if (mType === "Episode" || mType === "episode") return true
        if (activeMedia.seriesId || (activeMedia.rawData && activeMedia.rawData.SeriesId)) return true
        if (activeMedia.seasonId || (activeMedia.rawData && activeMedia.rawData.SeasonId)) return true
        return false
    }

    function playNextEpisode() {
        if (!activeMedia || !isEpisode) return
        console.log("[PLAYER] Requesting next episode for: " + (activeMedia.title || activeMedia.name || ""))
        AppData.getNextEpisode(activeMedia, function(nextEp) {
            if (nextEp && nextEp.id && nextEp.id !== activeMedia.id) {
                console.log("[PLAYER] Playing next episode: " + nextEp.title + " (ID: " + nextEp.id + ")")
                if (typeof mainShell !== "undefined" && mainShell) {
                    mainShell.selectedMediaItem = nextEp
                }
                playerOverlay.item = nextEp
            } else {
                console.log("[PLAYER] No next episode available. Exiting player.")
                exitPlayer()
            }
        })
    }

    function getResumePositionTicks(media) {
        if (!media) return 0
        if (media.rawData && media.rawData.UserData && media.rawData.UserData.PlaybackPositionTicks > 0) {
            return media.rawData.UserData.PlaybackPositionTicks
        }
        if (media.rawData && media.rawData.PlaybackPositionTicks > 0) {
            return media.rawData.PlaybackPositionTicks
        }
        if (media.PlaybackPositionTicks > 0) {
            return media.PlaybackPositionTicks
        }
        if (media.playbackPositionTicks > 0) {
            return media.playbackPositionTicks
        }
        if (media.resumePositionTicks > 0) {
            return media.resumePositionTicks
        }
        if (media.startPositionTicks > 0) {
            return media.startPositionTicks
        }
        if (media.progress > 0 && media.progress < 0.98 && media.rawData && media.rawData.RunTimeTicks > 0) {
            return Math.floor(media.progress * media.rawData.RunTimeTicks)
        }
        return 0
    }

    function getResumePositionSeconds(media) {
        var ticks = getResumePositionTicks(media)
        return Math.floor(ticks / 10000000)
    }

    property string streamUrl: {
        if (activeMedia && activeMedia.id && AppData.liveServerUrl && AppData.accessToken) {
            var mType = activeMedia.mediaType || activeMedia.Type || (activeMedia.rawData ? activeMedia.rawData.Type : "")
            var isAudio = (mType === "Audio" || mType === "MusicTrack" || mType === "MusicAlbum" || mType === "Playlist")
            if (isAudio) {
                return AppData.liveServerUrl + "/Audio/" + activeMedia.id + "/stream?static=true&api_key=" + AppData.accessToken
            }
            var msId = (activeMedia.rawData && activeMedia.rawData.MediaSources && activeMedia.rawData.MediaSources.length > 0) ? activeMedia.rawData.MediaSources[0].Id : activeMedia.id
            var maxBitrate = AppData.getMaxStreamingBitrateBps ? AppData.getMaxStreamingBitrateBps() : 20000000
            var url = AppData.liveServerUrl + "/Videos/" + activeMedia.id + "/master.m3u8?" +
                      "MediaSourceId=" + msId +
                      "&VideoCodec=h264,hevc" +
                      "&AudioCodec=aac,mp3" +
                      "&MaxStreamingBitrate=" + maxBitrate +
                      "&PlaySessionId=" + activeMedia.id + "_session" +
                      "&api_key=" + AppData.accessToken
            return url
        }
        return ""
    }

    // Fullscreen Pitch Black Canvas (renders seamless pitch-black letterbox & pillarbox bars)
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        z: -1
    }

    function applyInitialSeek() {
        if (pendingInitialSeek && targetResumePosition > 0) {
            console.log("[PLAYER] Applying initial resume seek to position: " + targetResumePosition + "s")
            mediaStreamPlayer.position = targetResumePosition * 1000
            if (typeof mediaStreamPlayer.setPosition === "function") {
                mediaStreamPlayer.setPosition(targetResumePosition * 1000)
            }
            pendingInitialSeek = false
        }
    }

    function togglePlayPause() {
        isPlaying = !isPlaying
    }

    function performSeek(targetSec) {
        targetSec = Math.max(0, Math.min(totalDuration, targetSec))
        currentPosition = targetSec
        mediaStreamPlayer.position = targetSec * 1000
        if (typeof mediaStreamPlayer.setPosition === "function") {
            mediaStreamPlayer.setPosition(targetSec * 1000)
        }
        if (activeMedia && activeMedia.id) {
            AppData.reportPlaybackProgress(activeMedia.id, currentPosition, !isPlaying, "seek")
        }
    }

    // Native Hardware-Accelerated Video Player
    MediaPlayer {
        id: mediaStreamPlayer
        source: playerOverlay.streamUrl
        videoOutput: videoOutput
        audioOutput: AudioOutput { id: audioOut; volume: 1.0 }

        onPositionChanged: {
            if (pendingInitialSeek) {
                applyInitialSeek()
            } else if (!isScrubbing && mediaStreamPlayer.position >= 0) {
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
            if (mediaStreamPlayer.playbackState === MediaPlayer.PlayingState && pendingInitialSeek) {
                applyInitialSeek()
            }
        }

        onMediaStatusChanged: {
            if (mediaStreamPlayer.mediaStatus === MediaPlayer.LoadedMedia || 
                mediaStreamPlayer.mediaStatus === MediaPlayer.BufferedMedia) {
                applyInitialSeek()
            }
            if (mediaStreamPlayer.mediaStatus === MediaPlayer.EndOfMedia) {
                if (activeMedia && activeMedia.id) {
                    AppData.reportPlaybackStopped(activeMedia.id, totalDuration)
                    AppData.fetchContinueWatching()
                }
                if (isEpisode) {
                    playNextEpisode()
                }
            }
        }
    }

    onIsPlayingChanged: {
        if (typeof SessionBridge !== "undefined" && SessionBridge && typeof SessionBridge.updateMprisState === "function") {
            var mediaTitle = activeMedia ? (activeMedia.name || activeMedia.title || "") : ""
            SessionBridge.updateMprisState(isPlaying ? "Playing" : "Paused", mediaTitle, "", "")
        }
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
        } else if (activeMedia && activeMedia.duration) {
            var parsedDur = parseFloat(activeMedia.duration)
            if (!isNaN(parsedDur) && parsedDur > 0) totalDuration = parsedDur
            else totalDuration = 1440.0
        } else {
            totalDuration = 1440.0
        }

        var resumeSec = getResumePositionSeconds(activeMedia)
        if (resumeSec > 0 && resumeSec < totalDuration - 10) {
            targetResumePosition = resumeSec
            currentPosition = resumeSec
            pendingInitialSeek = true
            console.log("[PLAYER] Resuming playback at " + resumeSec + " seconds (" + formatTime(resumeSec) + " / " + formatTime(totalDuration) + ")")
        } else {
            targetResumePosition = 0
            currentPosition = 0
            pendingInitialSeek = false
        }

        if (activeMedia && activeMedia.id) {
            console.log("[VIDEO PLAYER] Streaming video URL: " + streamUrl)
            AppData.reportPlaybackStart(activeMedia.id, currentPosition)
            mediaStreamPlayer.play()

            // Auto-enter fullscreen mode when show is added/played if not Plasma Bigscreen
            var isBigscreen = (typeof isPlasmaBigscreenEnv !== "undefined") ? isPlasmaBigscreenEnv : false
            if (!isBigscreen && typeof rootWindow !== "undefined" && rootWindow) {
                console.log("[PLAYER] Desktop environment detected: Auto entering Fullscreen mode")
                rootWindow.showFullScreen()
            }
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
        running: !playerOverlay.isBuffering
        repeat: false
        onTriggered: {
            if (!playerOverlay.isBuffering) {
                controlsContainer.visibleControls = false
            }
        }
    }

    function wakeControls() {
        controlsContainer.visibleControls = true
        autoHideTimer.restart()
    }

    property bool isBuffering: mediaStreamPlayer.mediaStatus === MediaPlayer.Buffering || 
                               mediaStreamPlayer.mediaStatus === MediaPlayer.StalledMedia || 
                               mediaStreamPlayer.mediaStatus === MediaPlayer.LoadingMedia

    onIsBufferingChanged: {
        if (isBuffering) {
            controlsContainer.visibleControls = true
            autoHideTimer.stop()
        } else {
            autoHideTimer.restart()
        }
    }

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

                        // Visual Handle Knob for Dragging / Scrubbing
                        Rectangle {
                            id: seekHandle
                            width: (seekTrack.activeFocus || seekMouseArea.containsMouse || playerOverlay.isScrubbing) ? 20 : 14
                            height: (seekTrack.activeFocus || seekMouseArea.containsMouse || playerOverlay.isScrubbing) ? 20 : 14
                            radius: height / 2
                            color: (seekTrack.activeFocus || playerOverlay.isScrubbing) ? "#00f0ff" : "#ffffff"
                            border.color: "#0284c7"
                            border.width: 2
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(seekTrack.width - width, (seekTrack.width * (totalDuration > 0 ? (currentPosition / totalDuration) : 0)) - width / 2))
                            Behavior on width { NumberAnimation { duration: 100 } }
                            Behavior on height { NumberAnimation { duration: 100 } }
                        }

                        function handleScrub(mouseX) {
                            if (seekTrack.width <= 0 || totalDuration <= 0) return
                            var ratio = Math.max(0, Math.min(1.0, mouseX / seekTrack.width))
                            currentPosition = ratio * totalDuration
                        }

                        MouseArea {
                            id: seekMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true

                            onPressed: function(mouse) {
                                wakeControls()
                                playerOverlay.isScrubbing = true
                                seekTrack.handleScrub(mouse.x)
                            }

                            onPositionChanged: function(mouse) {
                                if (pressed) {
                                    wakeControls()
                                    playerOverlay.isScrubbing = true
                                    seekTrack.handleScrub(mouse.x)
                                }
                            }

                            onReleased: function(mouse) {
                                wakeControls()
                                seekTrack.handleScrub(mouse.x)
                                playerOverlay.isScrubbing = false
                                performSeek(currentPosition)
                            }

                            onClicked: function(mouse) {
                                wakeControls()
                                seekTrack.handleScrub(mouse.x)
                                playerOverlay.isScrubbing = false
                                performSeek(currentPosition)
                            }
                        }

                        Keys.onLeftPressed: {
                            wakeControls()
                            performSeek(Math.max(0, currentPosition - 10))
                        }
                        Keys.onRightPressed: {
                            wakeControls()
                            performSeek(Math.min(totalDuration, currentPosition + 10))
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
                                performSeek(Math.max(0, currentPosition - 10))
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            performSeek(Math.max(0, currentPosition - 10))
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            performSeek(Math.max(0, currentPosition - 10))
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
                                performSeek(Math.min(totalDuration, currentPosition + 10))
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            performSeek(Math.min(totalDuration, currentPosition + 10))
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            performSeek(Math.min(totalDuration, currentPosition + 10))
                        }
                        Keys.onLeftPressed: playPauseBtn.forceActiveFocus()
                        Keys.onRightPressed: nextEpBtn.visible ? nextEpBtn.forceActiveFocus() : subBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    // Next Episode Button (visible when playing a TV Episode)
                    Rectangle {
                        id: nextEpBtn
                        width: 120
                        height: 40
                        radius: 20
                        visible: playerOverlay.isEpisode
                        color: activeFocus ? "#0284c7" : "#1e293b"
                        border.color: activeFocus ? "#00f0ff" : "#475569"
                        border.width: activeFocus ? 4 : 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Image {
                                width: 14
                                height: 14
                                source: "assets/icons/forward.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: "Next Ep"
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
                                playerOverlay.playNextEpisode()
                            }
                        }

                        Keys.onReturnPressed: {
                            wakeControls()
                            playerOverlay.playNextEpisode()
                        }
                        Keys.onSelectPressed: {
                            wakeControls()
                            playerOverlay.playNextEpisode()
                        }
                        Keys.onLeftPressed: forwardBtn.forceActiveFocus()
                        Keys.onRightPressed: subBtn.forceActiveFocus()
                        Keys.onUpPressed: seekTrack.forceActiveFocus()
                    }

                    Item { Layout.fillWidth: true }

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
                        Keys.onLeftPressed: nextEpBtn.visible ? nextEpBtn.forceActiveFocus() : forwardBtn.forceActiveFocus()
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
            performSeek(Math.max(0, currentPosition - 10))
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            performSeek(Math.min(totalDuration, currentPosition + 10))
            event.accepted = true
        } else if (event.key === Qt.Key_M) {
            audioOut.muted = !audioOut.muted
            event.accepted = true
        } else if (event.key === Qt.Key_D) {
            controlsContainer.visibleControls = !controlsContainer.visibleControls
            event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            if (!playPauseBtn.activeFocus && !rewindBtn.activeFocus && !forwardBtn.activeFocus && !seekTrack.activeFocus && !playerBackBtn.activeFocus && !subBtn.activeFocus) {
                playPauseBtn.forceActiveFocus()
            }
        }
    }
}
