import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: settingsView
    anchors.fill: parent

    signal requestSidebarFocus()
    signal backRequested()
    signal openSessionSwitcher()

    // ==========================================
    // BIGFIN SETTINGS ENGINE STATE
    // ==========================================
    property int activeCategory: -1

    // Category 0: Network & Server Settings (5 items)
    property string serverUrl: "http://localhost:8096"
    property bool autoDiscovery: true
    property bool sslBypass: false
    property var connectTimeouts: ["5 Seconds", "10 Seconds", "30 Seconds"]
    property int connectTimeoutIdx: 0

    // Category 1: Display & Interface (5 items)
    property string defaultStartupView: "home"
    property bool startupViewEnabled: true
    property var themeStyles: ["Midnight OLED Dark", "Cyberpunk Neon", "Deep Ocean"]
    property int themeStyleIdx: AppData.activeThemeIndex
    property bool diagnosticHudEnabled: true
    property var navSpeeds: ["Standard (60fps)", "Fast", "Instant"]
    property int navSpeedIdx: 0

    // Category 2: Video Playback & Bitrate (6 items)
    property var homeBitrates: ["120 Mbps (4K HDR)", "80 Mbps (1080p)", "40 Mbps (1080p)", "10 Mbps (720p)"]
    property int homeBitrateIdx: 0
    property var remoteBitrates: ["20 Mbps (1080p)", "10 Mbps (720p)", "Auto (Adaptive)"]
    property int remoteBitrateIdx: 0
    property bool directPlayHevc: true
    property bool directPlayAv1: true
    property var maxTranscodeResolutions: ["Auto 4K", "1080p Max", "720p Max"]
    property int maxTranscodeResIdx: 0
    property var resumeThresholds: ["5 Percent", "10 Percent", "Ask Every Time"]
    property int resumeThresholdIdx: 0

    // Category 3: Hardware GPU Acceleration (4 items)
    property var gpuRenderers: ["gpu-next (Vulkan)", "gpu (OpenGL)", "gpu-next (High Quality)"]
    property int gpuRendererIdx: 0
    property var hwDecoders: ["VAAPI / NVDEC (Native GPU)", "VDPAU (NVIDIA)", "CUDA Engine", "Software (CPU)"]
    property int hwDecoderIdx: 0
    property bool matchFrameRate: true
    property var deinterlaceModes: ["Auto YADIF", "Off", "B組織 Interlaced"]
    property int deinterlaceIdx: 0

    // Category 4: Audio Devices & Passthrough (5 items)
    property var audioOutputDevices: ["HDMI Passthrough", "PulseAudio Sound", "ALSA Raw System"]
    property int audioOutputIdx: 0
    property bool surroundPassthroughEnabled: true
    property var audioLanguages: ["English (aac/eac3)", "Japanese (flac/ac3)", "Spanish", "German"]
    property int audioLangIdx: 0
    property bool nightModeDrc: false
    property var stereoDialogueBoosts: ["Off", "Low (+3dB)", "High (+6dB)"]
    property int stereoDialogueIdx: 0

    // Category 5: Subtitles & Closed Captions (5 items)
    property var defaultSubModes: ["Auto-select SDH", "Always On", "Off / Forced Only"]
    property int subModeIdx: 0
    property var defaultSubLangs: ["English SDH", "Japanese", "Spanish", "French"]
    property int subLangIdx: 0
    property var burnInPolicies: ["Only Image ASS", "All Subtitles", "Direct Native Render"]
    property int burnInPolicyIdx: 0
    property var subFontSizes: ["Medium 24pt", "Large 28pt", "Small 20pt"]
    property int subFontSizeIdx: 0
    property var subTextColors: ["White", "Yellow", "Cyan"]
    property int subTextColorIdx: 0

    // Category 6: System Diagnostics & Cache (3 items)
    property string cacheSizeText: "2.4 GB Clean Cache"
    property bool debugLoggingEnabled: false

    property alias defaultFocusItem: masterListView

    // Clean Master Category Data Model
    readonly property var masterCategories: [
        { id: 0, title: "Network & Server Settings", desc: "Target server host URL, saved sessions, auto-discovery, SSL certificate bypass, timeout", icon: "assets/icons/logo.svg", itemCount: 5 },
        { id: 1, title: "Display & Startup Settings", desc: "Default startup view, theme palette, diagnostic HUD, navigation speed", icon: "assets/icons/home.svg", itemCount: 5 },
        { id: 2, title: "Video Playback & Bitrate Settings", desc: "Home/remote bitrate, HEVC/AV1 direct play, transcode limit, resume", icon: "assets/icons/play.svg", itemCount: 6 },
        { id: 3, title: "Hardware GPU Acceleration", desc: "libmpv video renderer engine, VAAPI / NVDEC decoder, AFR mode", icon: "assets/icons/tv.svg", itemCount: 4 },
        { id: 4, title: "Audio Devices & Passthrough", desc: "HDMI passthrough, surround sound, default audio track, DRC night mode", icon: "assets/icons/info.svg", itemCount: 5 },
        { id: 5, title: "Subtitles & Closed Captions", desc: "Subtitle selection mode, language priority, burn-in policy, font size", icon: "assets/icons/favorites.svg", itemCount: 5 },
        { id: 6, title: "System Diagnostics & Cache", desc: "Offline thumbnail cache, debug log output, settings reset", icon: "assets/icons/settings.svg", itemCount: 3 }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // 1. TOP HEADER & BACK NAVIGATION BAR
        // ==========================================
        Rectangle {
            id: topHeaderBar
            Layout.fillWidth: true
            height: 72
            color: "#080c14"
            border.color: "#1e293b"
            border.width: 1
            z: 10

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 20

                // Back Button (Top Left)
                Item {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignVCenter

                    Rectangle {
                        id: backBtn
                        anchors.fill: parent
                        radius: 8
                        color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                        border.color: activeFocus ? "#ffffff" : "#475569"
                        border.width: activeFocus ? 3 : 1
                        focus: true

                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 10

                            Image {
                                width: 18
                                height: 18
                                source: "assets/icons/arrow_left.svg"
                                fillMode: Image.PreserveAspectFit
                            }

                            Text {
                                text: settingsView.activeCategory === -1 ? "Back" : "Settings List"
                                font.pixelSize: 14
                                font.bold: true
                                color: backBtn.activeFocus ? "#0f172a" : "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                backBtn.forceActiveFocus()
                                handleBackAction()
                            }
                        }

                        Keys.onReturnPressed: handleBackAction()
                        Keys.onSpacePressed: handleBackAction()
                        Keys.onUpPressed: function(event) { event.accepted = true }
                        Keys.onDownPressed: function(event) {
                            if (settingsView.activeCategory === -1) masterListView.forceActiveFocus()
                            else detailListView.forceActiveFocus()
                            event.accepted = true
                        }
                        Keys.onLeftPressed: function(event) {
                            settingsView.requestSidebarFocus()
                            event.accepted = true
                        }
                    }
                }

                // Vertical Divider Line
                Rectangle {
                    width: 1
                    height: 32
                    color: "#334155"
                }

                // Clean Header Title
                Text {
                    text: settingsView.activeCategory === -1 ? "System Settings" : ("Settings  ›  " + settingsView.masterCategories[settingsView.activeCategory].title)
                    font.pixelSize: 22
                    font.bold: true
                    color: "#ffffff"
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // ==========================================
        // 2. MASTER CATEGORY LIST VIEW
        // ==========================================
        ListView {
            id: masterListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: settingsView.activeCategory === -1
            clip: true
            focus: true
            spacing: 4
            currentIndex: 0
            keyNavigationWraps: false
            highlightMoveDuration: 100

            model: settingsView.masterCategories

            onActiveFocusChanged: {
                if (activeFocus && currentItem) {
                    currentItem.forceActiveFocus()
                }
            }

            delegate: Item {
                id: masterDelegateItem
                width: masterListView.width
                height: 76
                focus: true

                onActiveFocusChanged: {
                    if (activeFocus) {
                        rowCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: rowCard
                    width: parent.width - 24
                    height: 72
                    anchors.centerIn: parent
                    radius: 8
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    focus: true

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            masterListView.currentIndex = index
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        radius: 4
                        color: AppData.currentTheme.accent
                        visible: rowCard.activeFocus
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 20

                        Image {
                            width: 26
                            height: 26
                            source: modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: modelData.title
                                font.pixelSize: 18
                                font.bold: true
                                color: rowCard.activeFocus ? "#ffffff" : "#f1f5f9"
                            }

                            Text {
                                text: modelData.desc
                                font.pixelSize: 13
                                color: rowCard.activeFocus ? "#e0f2fe" : "#94a3b8"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "›"
                            font.pixelSize: 28
                            font.bold: true
                            color: rowCard.activeFocus ? AppData.currentTheme.accent : "#475569"
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: openCategoryDetail(index)
                    }

                    Keys.onReturnPressed: openCategoryDetail(index)
                    Keys.onSpacePressed: openCategoryDetail(index)
                    Keys.onRightPressed: openCategoryDetail(index)

                    Keys.onLeftPressed: function(event) {
                        settingsView.requestSidebarFocus()
                        event.accepted = true
                    }

                    Keys.onUpPressed: function(event) {
                        if (index === 0) {
                            backBtn.forceActiveFocus()
                        } else {
                            masterListView.decrementCurrentIndex()
                            if (masterListView.currentItem) masterListView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onDownPressed: function(event) {
                        if (index < masterListView.count - 1) {
                            masterListView.incrementCurrentIndex()
                            if (masterListView.currentItem) masterListView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }
                }
            }
        }

        // ==========================================
        // 3. DETAIL OPTIONS LIST VIEW
        // ==========================================
        ListView {
            id: detailListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: settingsView.activeCategory >= 0
            clip: true
            focus: true
            spacing: 4
            currentIndex: 0
            keyNavigationWraps: false
            highlightMoveDuration: 100

            model: settingsView.getCategoryItemCount(settingsView.activeCategory)

            onActiveFocusChanged: {
                if (activeFocus && currentItem) {
                    currentItem.forceActiveFocus()
                }
            }

            delegate: Item {
                id: detailDelegateItem
                width: detailListView.width
                height: 76
                focus: true

                onActiveFocusChanged: {
                    if (activeFocus) {
                        detailRowCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: detailRowCard
                    width: parent.width - 24
                    height: 72
                    anchors.centerIn: parent
                    radius: 8
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    focus: true

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            detailListView.currentIndex = index
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 8
                        radius: 4
                        color: AppData.currentTheme.accent
                        visible: detailRowCard.activeFocus
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        spacing: 20

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: settingsView.getSubTitle(settingsView.activeCategory, index)
                                font.pixelSize: 18
                                font.bold: true
                                color: detailRowCard.activeFocus ? "#ffffff" : "#f1f5f9"
                            }

                            Text {
                                text: settingsView.getSubDesc(settingsView.activeCategory, index)
                                font.pixelSize: 13
                                color: detailRowCard.activeFocus ? "#e0f2fe" : "#94a3b8"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Right Aligned Action Box / Editable Input Bar
                        Item {
                            width: 260
                            height: 44

                            // EDITABLE TEXT INPUT FIELD FOR JELLYFIN TARGET SERVER ADDRESS
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: "#090d16"
                                border.color: serverInput.activeFocus ? AppData.currentTheme.accent : "#334155"
                                border.width: serverInput.activeFocus ? 2 : 1
                                visible: settingsView.activeCategory === 0 && index === 0

                                TextField {
                                    id: serverInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    text: settingsView.serverUrl
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                    background: null

                                    onTextChanged: {
                                        settingsView.serverUrl = text
                                        AppData.liveServerUrl = text
                                    }

                                    Keys.onUpPressed: function(event) {
                                        backBtn.forceActiveFocus()
                                        event.accepted = true
                                    }
                                    Keys.onDownPressed: function(event) {
                                        detailListView.incrementCurrentIndex()
                                        if (detailListView.currentItem) detailListView.currentItem.forceActiveFocus()
                                        event.accepted = true
                                    }
                                    Keys.onLeftPressed: function(event) {
                                        if (cursorPosition === 0) {
                                            settingsView.requestSidebarFocus()
                                            event.accepted = true
                                        }
                                    }
                                }
                            }

                            // REGULAR BUTTON BOX FOR OTHER OPTIONS
                            Rectangle {
                                anchors.fill: parent
                                radius: 8
                                color: detailRowCard.activeFocus ? AppData.currentTheme.accent : "#1e293b"
                                border.color: detailRowCard.activeFocus ? "#ffffff" : "#475569"
                                border.width: 1
                                visible: !(settingsView.activeCategory === 0 && index === 0)

                                Text {
                                    anchors.centerIn: parent
                                    text: settingsView.getSubValue(settingsView.activeCategory, index)
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: detailRowCard.activeFocus ? "#0f172a" : "#ffffff"
                                }
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            detailRowCard.forceActiveFocus()
                            settingsView.triggerSubAction(settingsView.activeCategory, index)
                        }
                    }

                    Keys.onReturnPressed: settingsView.triggerSubAction(settingsView.activeCategory, index)
                    Keys.onSpacePressed: settingsView.triggerSubAction(settingsView.activeCategory, index)

                    Keys.onLeftPressed: function(event) {
                        settingsView.requestSidebarFocus()
                        event.accepted = true
                    }

                    Keys.onUpPressed: function(event) {
                        if (index === 0) {
                            backBtn.forceActiveFocus()
                        } else {
                            detailListView.decrementCurrentIndex()
                            if (detailListView.currentItem) detailListView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onDownPressed: function(event) {
                        if (index < detailListView.count - 1) {
                            detailListView.incrementCurrentIndex()
                            if (detailListView.currentItem) detailListView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }
                }
            }
        }
    }

    function openCategoryDetail(catIdx) {
        settingsView.activeCategory = catIdx
        Qt.callLater(function() {
            if (detailListView) {
                detailListView.currentIndex = 0
                detailListView.forceActiveFocus()
                if (detailListView.currentItem) {
                    detailListView.currentItem.forceActiveFocus()
                }
            }
        })
    }

    function handleBackAction() {
        if (activeCategory >= 0) {
            activeCategory = -1
            Qt.callLater(function() {
                if (masterListView) {
                    masterListView.currentIndex = 0
                    masterListView.forceActiveFocus()
                    if (masterListView.currentItem) {
                        masterListView.currentItem.forceActiveFocus()
                    }
                }
            })
        } else {
            backRequested()
        }
    }

    function getCategoryItemCount(catIdx) {
        if (catIdx < 0 || catIdx >= masterCategories.length) return 0
        return masterCategories[catIdx].itemCount
    }

    function getSubTitle(catIdx, itemIdx) {
        if (catIdx === 0) {
            if (itemIdx === 0) return "Jellyfin Target Server Host URL"
            if (itemIdx === 1) return "Saved User Sessions & Accounts"
            if (itemIdx === 2) return "Automatic Server Discovery"
            if (itemIdx === 3) return "SSL Certificate Validation"
            return "Network Connect Timeout"
        }
        if (catIdx === 1) {
            if (itemIdx === 0) return "Default Startup View"
            if (itemIdx === 1) return "Enable Custom Start Screen"
            if (itemIdx === 2) return "10-Foot TV Design Theme"
            if (itemIdx === 3) return "Diagnostic HUD Overlay"
            return "D-Pad TV Navigation Speed"
        }
        if (catIdx === 2) {
            if (itemIdx === 0) return "Home Network Bitrate Limit"
            if (itemIdx === 1) return "Remote Cellular Bitrate Limit"
            if (itemIdx === 2) return "Direct Play HEVC / H.265 Streams"
            if (itemIdx === 3) return "Direct Play AV1 Codec"
            if (itemIdx === 4) return "Max Transcode Resolution"
            return "Video Playback Resume Threshold"
        }
        if (catIdx === 3) {
            if (itemIdx === 0) return "libmpv Video Renderer Engine"
            if (itemIdx === 1) return "Hardware Video Decoder API"
            if (itemIdx === 2) return "Auto Frame Rate Matching (AFR)"
            return "Deinterlacing Filter Mode"
        }
        if (catIdx === 4) {
            if (itemIdx === 0) return "Audio Output Device & Driver"
            if (itemIdx === 1) return "Surround Sound Passthrough"
            if (itemIdx === 2) return "Default Audio Language Track"
            if (itemIdx === 3) return "Dynamic Range Compression (DRC)"
            return "Downmix Stereo Dialogue Boost"
        }
        if (catIdx === 5) {
            if (itemIdx === 0) return "Default Subtitle Selection Mode"
            if (itemIdx === 1) return "Default Subtitle Language"
            if (itemIdx === 2) return "Subtitle Burn-In Policy"
            if (itemIdx === 3) return "Subtitle Font Size"
            return "Subtitle Text Color"
        }
        if (catIdx === 6) {
            if (itemIdx === 0) return "Offline Storage & Metadata Cache"
            if (itemIdx === 1) return "Enable Debug Log Output"
            return "Reset Bigfin Configuration"
        }
        return "Option " + (itemIdx + 1)
    }

    function getSubDesc(catIdx, itemIdx) {
        if (catIdx === 0) {
            if (itemIdx === 0) return "Type single or multiple Jellyfin server IP addresses (e.g. 192.168.1.50, 10.0.0.5)"
            if (itemIdx === 1) return "View active accounts, switch sessions, or log into another server"
            if (itemIdx === 2) return "Automatically locate Jellyfin instances on local Wi-Fi / LAN"
            if (itemIdx === 3) return "Bypass self-signed SSL certificate warnings for local servers"
            return "Timeout threshold when attempting to connect to Jellyfin host"
        }
        if (catIdx === 1) {
            if (itemIdx === 0) return "Select which view launches automatically when opening Bigfin"
            if (itemIdx === 1) return "Open directly into your chosen startup screen instead of Home"
            if (itemIdx === 2) return "Select theme (Midnight OLED Dark, Cyberpunk Neon, Deep Ocean)"
            if (itemIdx === 3) return "Show active focus and key input HUD overlay (Press 'D')"
            return "D-Pad arrow key repeat speed for 10-foot TV remotes"
        }
        if (catIdx === 2) {
            if (itemIdx === 0) return "Maximum bitrate limit before Jellyfin server transcodes stream"
            if (itemIdx === 1) return "Bitrate threshold when streaming outside local home network"
            if (itemIdx === 2) return "Bypass transcoding for native H.265 / HEVC hardware streams"
            if (itemIdx === 3) return "Bypass transcoding for next-gen AV1 open video streams"
            if (itemIdx === 4) return "Upper resolution bound if video must be transcoded"
            return "Minimum playback progress percentage before saving resume point"
        }
        return "Configure option settings"
    }

    function getSubValue(catIdx, itemIdx) {
        if (catIdx === 0) {
            if (itemIdx === 0) return serverUrl
            if (itemIdx === 1) return AppData.savedSessions.length + " Saved Sessions"
            if (itemIdx === 2) return autoDiscovery ? "ENABLED" : "DISABLED"
            if (itemIdx === 3) return sslBypass ? "BYPASS" : "STRICT HTTPS"
            return connectTimeouts[connectTimeoutIdx]
        }
        if (catIdx === 1) {
            if (itemIdx === 0) return defaultStartupView === "home" ? "Home 🔄" : (defaultStartupView === "movies" ? "Movies 🔄" : "Search 🔄")
            if (itemIdx === 1) return startupViewEnabled ? "ENABLED" : "DISABLED"
            if (itemIdx === 2) return themeStyles[themeStyleIdx]
            if (itemIdx === 3) return diagnosticHudEnabled ? "ENABLED" : "DISABLED"
            return navSpeeds[navSpeedIdx]
        }
        if (catIdx === 2) {
            if (itemIdx === 0) return homeBitrates[homeBitrateIdx]
            if (itemIdx === 1) return remoteBitrates[remoteBitrateIdx]
            if (itemIdx === 2) return directPlayHevc ? "ENABLED" : "DISABLED"
            if (itemIdx === 3) return directPlayAv1 ? "ENABLED" : "DISABLED"
            if (itemIdx === 4) return maxTranscodeResolutions[maxTranscodeResIdx]
            return resumeThresholds[resumeThresholdIdx]
        }
        if (catIdx === 3) {
            if (itemIdx === 0) return gpuRenderers[gpuRendererIdx]
            if (itemIdx === 1) return hwDecoders[hwDecoderIdx]
            if (itemIdx === 2) return matchFrameRate ? "MATCH HZ (ON)" : "DISABLED"
            return deinterlaceModes[deinterlaceIdx]
        }
        if (catIdx === 4) {
            if (itemIdx === 0) return audioOutputDevices[audioOutputIdx]
            if (itemIdx === 1) return surroundPassthroughEnabled ? "5.1 / 7.1 ATMOS" : "STEREO PCM"
            if (itemIdx === 2) return audioLanguages[audioLangIdx]
            if (itemIdx === 3) return nightModeDrc ? "NIGHT MODE ON" : "OFF"
            return stereoDialogueBoosts[stereoDialogueIdx]
        }
        if (catIdx === 5) {
            if (itemIdx === 0) return defaultSubModes[subModeIdx]
            if (itemIdx === 1) return defaultSubLangs[subLangIdx]
            if (itemIdx === 2) return burnInPolicies[burnInPolicyIdx]
            if (itemIdx === 3) return subFontSizes[subFontSizeIdx]
            return subTextColors[subTextColorIdx]
        }
        if (catIdx === 6) {
            if (itemIdx === 0) return cacheSizeText
            if (itemIdx === 1) return debugLoggingEnabled ? "ENABLED" : "DISABLED"
            return "RESET TO DEFAULT"
        }
        return "ENABLED"
    }

    function triggerSubAction(catIdx, itemIdx) {
        if (catIdx === 0) {
            if (itemIdx === 0) return
            else if (itemIdx === 1) openSessionSwitcher()
            else if (itemIdx === 2) autoDiscovery = !autoDiscovery
            else if (itemIdx === 3) sslBypass = !sslBypass
            else connectTimeoutIdx = (connectTimeoutIdx + 1) % connectTimeouts.length
        }
        else if (catIdx === 1) {
            if (itemIdx === 0) cycleStartupView()
            else if (itemIdx === 1) startupViewEnabled = !startupViewEnabled
            else if (itemIdx === 2) {
                themeStyleIdx = (themeStyleIdx + 1) % themeStyles.length
                AppData.activeThemeIndex = themeStyleIdx
            }
            else if (itemIdx === 3) diagnosticHudEnabled = !diagnosticHudEnabled
            else navSpeedIdx = (navSpeedIdx + 1) % navSpeeds.length
        }
        else if (catIdx === 2) {
            if (itemIdx === 0) homeBitrateIdx = (homeBitrateIdx + 1) % homeBitrates.length
            else if (itemIdx === 1) remoteBitrateIdx = (remoteBitrateIdx + 1) % remoteBitrates.length
            else if (itemIdx === 2) directPlayHevc = !directPlayHevc
            else if (itemIdx === 3) directPlayAv1 = !directPlayAv1
            else if (itemIdx === 4) maxTranscodeResIdx = (maxTranscodeResIdx + 1) % maxTranscodeResolutions.length
            else resumeThresholdIdx = (resumeThresholdIdx + 1) % resumeThresholds.length
        }
        else if (catIdx === 3) {
            if (itemIdx === 0) gpuRendererIdx = (gpuRendererIdx + 1) % gpuRenderers.length
            else if (itemIdx === 1) hwDecoderIdx = (hwDecoderIdx + 1) % hwDecoders.length
            else if (itemIdx === 2) matchFrameRate = !matchFrameRate
            else deinterlaceIdx = (deinterlaceIdx + 1) % deinterlaceModes.length
        }
        else if (catIdx === 4) {
            if (itemIdx === 0) audioOutputIdx = (audioOutputIdx + 1) % audioOutputDevices.length
            else if (itemIdx === 1) surroundPassthroughEnabled = !surroundPassthroughEnabled
            else if (itemIdx === 2) audioLangIdx = (audioLangIdx + 1) % audioLanguages.length
            else if (itemIdx === 3) nightModeDrc = !nightModeDrc
            else stereoDialogueIdx = (stereoDialogueIdx + 1) % stereoDialogueBoosts.length
        }
        else if (catIdx === 5) {
            if (itemIdx === 0) subModeIdx = (subModeIdx + 1) % defaultSubModes.length
            else if (itemIdx === 1) subLangIdx = (subLangIdx + 1) % defaultSubLangs.length
            else if (itemIdx === 2) burnInPolicyIdx = (burnInPolicyIdx + 1) % burnInPolicies.length
            else if (itemIdx === 3) subFontSizeIdx = (subFontSizeIdx + 1) % subFontSizes.length
            else subTextColorIdx = (subTextColorIdx + 1) % subTextColors.length
        }
        else if (catIdx === 6) {
            if (itemIdx === 0) {
                if (cacheSizeText === "2.4 GB Clean Cache") cacheSizeText = "0 MB (Cleared)"
                else cacheSizeText = "2.4 GB Clean Cache"
            }
            else if (itemIdx === 1) debugLoggingEnabled = !debugLoggingEnabled
            else {
                serverUrl = "http://localhost:8096"; autoDiscovery = true; sslBypass = false;
                startupViewEnabled = true; themeStyleIdx = 0; AppData.activeThemeIndex = 0;
            }
        }
    }

    function cycleStartupView() {
        if (defaultStartupView === "home") defaultStartupView = "movies"
        else if (defaultStartupView === "movies") defaultStartupView = "tvshows"
        else if (defaultStartupView === "tvshows") defaultStartupView = "search"
        else defaultStartupView = "home"
    }
}
