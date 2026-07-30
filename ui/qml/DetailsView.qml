import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: detailsView
    anchors.fill: parent

    signal playRequested(var item)
    signal backRequested()
    signal requestSidebarFocus()

    property var item: AppData.featuredHero
    property alias defaultFocusItem: playBtn

    function getItemType() {
        if (!item) return "Movie"
        var t = item.mediaType || (item.rawData ? item.rawData.Type : "")
        if (t === "Episode" || t === "episode") return "Episode"
        if (t === "Series" || t === "series" || t === "Show" || t === "TvShow") return "Series"
        return "Movie"
    }

    readonly property string itemType: getItemType()
    readonly property bool isEpisode: itemType === "Episode"
    readonly property bool isSeries: itemType === "Series"

    function getSeriesId() {
        if (!item) return ""
        if (isSeries) return item.id || ""
        if (item.seriesId) return item.seriesId
        if (item.rawData && item.rawData.SeriesId) return item.rawData.SeriesId
        return ""
    }

    function getEndsAtString(durationStr) {
        var durMins = 22
        if (durationStr) {
            var p = parseInt(durationStr)
            if (!isNaN(p) && p > 0) durMins = p
        }
        var now = new Date()
        var end = new Date(now.getTime() + durMins * 60000)
        var h = end.getHours()
        var m = end.getMinutes()
        var ampm = h >= 12 ? 'PM' : 'AM'
        h = h % 12
        h = h ? h : 12
        var mStr = m < 10 ? ('0' + m) : m
        return "Ends at " + h + ":" + mStr + " " + ampm
    }

    property var seasonsList: []
    property var episodesList: []
    property var nextUpEpisode: null
    property var activeSeason: null

    onItemChanged: loadData()
    onVisibleChanged: { if (visible) loadData() }

    function loadData() {
        seasonsList = []
        episodesList = []
        nextUpEpisode = null
        activeSeason = null

        var sId = getSeriesId()
        console.log("[DETAILS] loadData. Item: " + (item ? item.title : "null") + " | Type: " + itemType + " | Series ID: " + sId)

        if (isSeries) {
            AppData.fetchNextUpForSeries(sId, function(nextEp) {
                if (nextEp) nextUpEpisode = nextEp
            })
            AppData.fetchSeasons(sId, function(seasons) {
                if (seasons && seasons.length > 0) {
                    seasonsList = seasons
                    loadSeasonEpisodes(seasons[0])
                } else {
                    seasonsList = []
                    episodesList = []
                }
            })
        } else if (isEpisode && sId !== "") {
            var seasonIdToFetch = item.seasonId || ""
            AppData.fetchEpisodes(sId, seasonIdToFetch, function(episodes) {
                episodesList = episodes
            })
        }
    }

    function loadSeasonEpisodes(seasonObj) {
        activeSeason = seasonObj
        var targetId = getSeriesId()
        var sId = seasonObj ? seasonObj.id : ""
        console.log("[DETAILS] Fetching episodes for Series ID: " + targetId + " | Season ID: " + sId)
        AppData.fetchEpisodes(targetId, sId, function(episodes) {
            episodesList = episodes
        })
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainDetailsColumn.implicitHeight + 100
        clip: true

        // Backdrop Ambient Image
        Image {
            anchors.fill: parent
            source: detailsView.item ? (detailsView.item.backdropUrl || detailsView.item.posterUrl) : ""
            fillMode: Image.PreserveAspectCrop
            opacity: 0.28
        }

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#e60b0e17" }
                GradientStop { position: 0.5; color: "#f20b0e17" }
                GradientStop { position: 1.0; color: "#0b0e17" }
            }
        }

        ColumnLayout {
            id: mainDetailsColumn
            width: parent.width
            spacing: 28

            // Top Back Button Row
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                Layout.topMargin: 24

                Rectangle {
                    id: backBtn
                    width: 110
                    height: 40
                    radius: 8
                    color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.color: activeFocus ? "#ffffff" : "#475569"
                    border.width: activeFocus ? 2 : 1
                    focus: true

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Image {
                            width: 16
                            height: 16
                            source: "assets/icons/arrow_left.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Text { text: "Back"; font.pixelSize: 14; font.bold: true; color: backBtn.activeFocus ? "#0f172a" : "#ffffff" }
                    }

                    MouseArea { onClicked: detailsView.backRequested() }
                    Keys.onReturnPressed: detailsView.backRequested()
                    Keys.onSpacePressed: detailsView.backRequested()
                    Keys.onDownPressed: function(event) { playBtn.forceActiveFocus(); event.accepted = true }
                    Keys.onLeftPressed: function(event) { detailsView.requestSidebarFocus(); event.accepted = true }
                }
            }

            // Top Header & Hero Content Row
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 40

                // Left Poster Box
                Rectangle {
                    Layout.preferredWidth: 300
                    Layout.preferredHeight: 440
                    radius: 16
                    color: "#0f172a"
                    border.color: AppData.currentTheme.accent
                    border.width: 2
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: detailsView.item ? (detailsView.item.posterUrl || detailsView.item.backdropUrl) : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                    }
                }

                // Right Metadata Column
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Main Title (Series Name if Episode, else Title)
                    Text {
                        text: {
                            if (!detailsView.item) return ""
                            if (detailsView.isEpisode) return detailsView.item.seriesName || detailsView.item.title || "TV Episode"
                            return detailsView.item.title || ""
                        }
                        font.pixelSize: 38
                        font.bold: true
                        color: "#ffffff"
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    // Subtitle (Season & Episode info if Episode, Content Rating if Series)
                    RowLayout {
                        spacing: 12
                        visible: detailsView.isEpisode || (detailsView.item && detailsView.item.officialRating)

                        // Content Rating Pill (e.g. TV-Y7, TV-14, TV-MA)
                        Rectangle {
                            visible: detailsView.item && detailsView.item.officialRating !== ""
                            width: 65
                            height: 24
                            radius: 4
                            color: "#334155"
                            border.color: "#64748b"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: detailsView.item ? (detailsView.item.officialRating || "TV-Y7") : "TV-Y7"
                                font.pixelSize: 11
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        Text {
                            text: {
                                if (!detailsView.item) return ""
                                if (detailsView.isEpisode) {
                                    var s = detailsView.item.seasonNumber || "1"
                                    var e = detailsView.item.episodeNumber ? (detailsView.item.episodeNumber + ". ") : ""
                                    var name = detailsView.item.episodeName || detailsView.item.title
                                    return "Season " + s + " - " + e + name
                                }
                                return ""
                            }
                            font.pixelSize: 18
                            font.bold: true
                            color: "#e2e8f0"
                            visible: detailsView.isEpisode
                        }
                    }

                    // Metadata Line: Star Rating, Release Date / Duration / Ends At
                    RowLayout {
                        spacing: 16

                        Text {
                            text: detailsView.item ? ("★ " + detailsView.item.rating) : ""
                            font.pixelSize: 17
                            font.bold: true
                            color: "#fbbf24"
                        }

                        Text {
                            text: {
                                if (!detailsView.item) return ""
                                if (detailsView.isEpisode) {
                                    var date = detailsView.item.premiereDate || detailsView.item.year || "2019"
                                    var dur = detailsView.item.duration || "22m"
                                    var endsAt = detailsView.getEndsAtString(dur)
                                    return date + "   " + dur + "   " + endsAt
                                }
                                var y = detailsView.item.year || "2024"
                                var d = detailsView.item.duration || "22m"
                                var typeStr = detailsView.isSeries ? "TV Series" : "Movie"
                                return y + " • " + d + " • " + typeStr
                            }
                            font.pixelSize: 15
                            color: "#94a3b8"
                        }
                    }

                    // Action Buttons Row (Play, Mark Played Checkmark, Favorite Heart, Options)
                    RowLayout {
                        spacing: 14
                        Layout.topMargin: 6

                        // Play Button
                        Rectangle {
                            id: playBtn
                            width: 150
                            height: 48
                            radius: 10
                            color: activeFocus ? AppData.currentTheme.focusCard : "#0f172a"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#0284c7"
                            border.width: activeFocus ? 4 : 2
                            focus: true

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Image {
                                    width: 18
                                    height: 18
                                    source: "assets/icons/play.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text { text: detailsView.isSeries ? "Play Show" : "Play"; font.pixelSize: 15; font.bold: true; color: "#ffffff" }
                            }

                            MouseArea { onClicked: detailsView.playRequested(detailsView.item) }
                            Keys.onReturnPressed: detailsView.playRequested(detailsView.item)
                            Keys.onSpacePressed: detailsView.playRequested(detailsView.item)
                            Keys.onUpPressed: function(event) { backBtn.forceActiveFocus(); event.accepted = true }
                            Keys.onLeftPressed: function(event) { detailsView.requestSidebarFocus(); event.accepted = true }
                            Keys.onRightPressed: function(event) {
                                if (nextUpBtn.visible) nextUpBtn.forceActiveFocus()
                                else playedBtn.forceActiveFocus()
                                event.accepted = true
                            }
                        }

                        // Play Next Episode Button (Series Only)
                        Rectangle {
                            id: nextUpBtn
                            visible: detailsView.isSeries && detailsView.nextUpEpisode !== null
                            width: 180
                            height: 48
                            radius: 10
                            color: activeFocus ? AppData.currentTheme.focusCard : "#1e1b4b"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#6366f1"
                            border.width: activeFocus ? 4 : 2

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "▶"; font.pixelSize: 14; color: "#818cf8" }
                                Text {
                                    text: detailsView.nextUpEpisode ? ("Play Next (" + (detailsView.nextUpEpisode.title || "Episode") + ")") : "Play Next"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 130
                                }
                            }

                            MouseArea { onClicked: detailsView.playRequested(detailsView.nextUpEpisode) }
                            Keys.onReturnPressed: detailsView.playRequested(detailsView.nextUpEpisode)
                            Keys.onSpacePressed: detailsView.playRequested(detailsView.nextUpEpisode)
                            Keys.onLeftPressed: function(event) { playBtn.forceActiveFocus(); event.accepted = true }
                            Keys.onRightPressed: function(event) { playedBtn.forceActiveFocus(); event.accepted = true }
                        }

                        // Mark Played / Watched Toggle Button (✓)
                        Rectangle {
                            id: playedBtn
                            width: 48
                            height: 48
                            radius: 10
                            color: activeFocus ? AppData.currentTheme.focusCard : (isPlayed ? "#064e3b" : "#1e293b")
                            border.color: activeFocus ? AppData.currentTheme.accent : (isPlayed ? "#10b981" : "#475569")
                            border.width: activeFocus ? 3 : 1

                            property bool isPlayed: detailsView.item ? (detailsView.item.isPlayed || false) : false

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 20
                                font.bold: true
                                color: playedBtn.isPlayed ? "#10b981" : "#94a3b8"
                            }

                            MouseArea {
                                onClicked: {
                                    playedBtn.isPlayed = !playedBtn.isPlayed
                                }
                            }
                            Keys.onReturnPressed: playedBtn.isPlayed = !playedBtn.isPlayed
                            Keys.onSpacePressed: playedBtn.isPlayed = !playedBtn.isPlayed
                            Keys.onLeftPressed: function(event) {
                                if (nextUpBtn.visible) nextUpBtn.forceActiveFocus()
                                else playBtn.forceActiveFocus()
                                event.accepted = true
                            }
                            Keys.onRightPressed: function(event) { favBtn.forceActiveFocus(); event.accepted = true }
                        }

                        // Favorite Heart/Star Toggle Button (♥ / ★)
                        Rectangle {
                            id: favBtn
                            width: 48
                            height: 48
                            radius: 10
                            color: activeFocus ? AppData.currentTheme.focusCard : (isFav ? "#831843" : "#1e293b")
                            border.color: activeFocus ? AppData.currentTheme.accent : (isFav ? "#f43f5e" : "#475569")
                            border.width: activeFocus ? 3 : 1

                            property bool isFav: detailsView.item ? (detailsView.item.isFavorite || false) : false

                            Text {
                                anchors.centerIn: parent
                                text: favBtn.isFav ? "♥" : "♡"
                                font.pixelSize: 22
                                color: favBtn.isFav ? "#f43f5e" : "#94a3b8"
                            }

                            MouseArea {
                                onClicked: {
                                    if (detailsView.item && detailsView.item.id) {
                                        favBtn.isFav = !favBtn.isFav
                                        AppData.toggleFavorite(detailsView.item.id, favBtn.isFav)
                                    }
                                }
                            }
                            Keys.onReturnPressed: {
                                if (detailsView.item && detailsView.item.id) {
                                    favBtn.isFav = !favBtn.isFav
                                    AppData.toggleFavorite(detailsView.item.id, favBtn.isFav)
                                }
                            }
                            Keys.onSpacePressed: {
                                if (detailsView.item && detailsView.item.id) {
                                    favBtn.isFav = !favBtn.isFav
                                    AppData.toggleFavorite(detailsView.item.id, favBtn.isFav)
                                }
                            }
                            Keys.onLeftPressed: function(event) { playedBtn.forceActiveFocus(); event.accepted = true }
                        }
                    }

                    // Technical Specs Table (Video, Audio, Subtitles - Matches Screenshot #1)
                    ColumnLayout {
                        visible: detailsView.isEpisode || !detailsView.isSeries
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        spacing: 6

                        RowLayout {
                            spacing: 24
                            Text { text: "Video"; font.pixelSize: 13; font.bold: true; color: "#94a3b8"; Layout.preferredWidth: 70 }
                            Text { text: detailsView.item ? (detailsView.item.videoSpec || "1080p H264 SDR") : "1080p H264 SDR"; font.pixelSize: 13; color: "#e2e8f0" }
                        }

                        RowLayout {
                            spacing: 24
                            Text { text: "Audio"; font.pixelSize: 13; font.bold: true; color: "#94a3b8"; Layout.preferredWidth: 70 }
                            Text { text: detailsView.item ? (detailsView.item.audioSpec || "English - Dolby Digital+ - 5.1 - Default") : "English - Dolby Digital+ - 5.1 - Default"; font.pixelSize: 13; color: "#e2e8f0" }
                        }

                        RowLayout {
                            spacing: 24
                            Text { text: "Subtitles"; font.pixelSize: 13; font.bold: true; color: "#94a3b8"; Layout.preferredWidth: 70 }
                            
                            Rectangle {
                                width: 200
                                height: 32
                                radius: 6
                                color: subCombo.activeFocus ? AppData.currentTheme.focusCard : "#1e293b"
                                border.color: subCombo.activeFocus ? AppData.currentTheme.accent : "#475569"
                                border.width: 1
                                id: subCombo
                                focus: true

                                Text {
                                    anchors.centerIn: parent
                                    text: "Off ▾"
                                    font.pixelSize: 13
                                    color: "#ffffff"
                                }
                            }
                        }
                    }

                    // Overview Paragraph
                    Text {
                        text: detailsView.item ? (detailsView.item.overview || "Jellyfin media details overview...") : ""
                        font.pixelSize: 14
                        color: "#cbd5e1"
                        wrapMode: Text.WordWrap
                        lineHeight: 1.3
                        maximumLineCount: 5
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                    }

                    // Tags & External Links & Genres (Matches Screenshot #1 & #2)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Layout.topMargin: 4

                        // Tags Row
                        RowLayout {
                            visible: detailsView.item && detailsView.item.tags && detailsView.item.tags !== ""
                            spacing: 10
                            Text { text: "Tags:"; font.pixelSize: 13; font.bold: true; color: "#94a3b8" }
                            Text {
                                text: detailsView.item ? detailsView.item.tags : ""
                                font.pixelSize: 13
                                color: "#cbd5e1"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // External Links (IMDb, TMDB)
                        RowLayout {
                            spacing: 12
                            Text { text: "IMDb"; font.pixelSize: 13; font.bold: true; color: "#fbbf24" }
                            Text { text: "TMDB"; font.pixelSize: 13; font.bold: true; color: "#38bdf8" }
                        }

                        // Genres & Studio Row
                        RowLayout {
                            spacing: 20

                            RowLayout {
                                spacing: 8
                                Text { text: "Genres:"; font.pixelSize: 13; font.bold: true; color: "#94a3b8" }
                                Text {
                                    text: detailsView.item && detailsView.item.genres ? (Array.isArray(detailsView.item.genres) ? detailsView.item.genres.join(", ") : detailsView.item.genres) : "Animation, Action, Adventure"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            RowLayout {
                                visible: detailsView.item && detailsView.item.studio && detailsView.item.studio !== ""
                                spacing: 8
                                Text { text: "Studio:"; font.pixelSize: 13; font.bold: true; color: "#94a3b8" }
                                Text {
                                    text: detailsView.item ? detailsView.item.studio : ""
                                    font.pixelSize: 13
                                    color: "#ffffff"
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // NEXT UP SECTION (TV SHOW VIEW ONLY)
            // ==========================================
            ColumnLayout {
                visible: detailsView.isSeries && detailsView.nextUpEpisode !== null
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 12

                Text {
                    text: "Next Up"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#ffffff"
                }

                Rectangle {
                    width: 240
                    height: 170
                    radius: 12
                    color: nextUpCardMouse.containsMouse ? AppData.currentTheme.focusCard : "#090d16"
                    border.color: "#1e293b"
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: "#020617"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: detailsView.nextUpEpisode ? (detailsView.nextUpEpisode.backdropUrl || detailsView.nextUpEpisode.posterUrl) : ""
                                fillMode: Image.PreserveAspectCrop
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36
                                height: 36
                                radius: 18
                                color: "#cc0f172a"
                                Image {
                                    anchors.centerIn: parent
                                    width: 16
                                    height: 16
                                    source: "assets/icons/play.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                        }

                        Text {
                            text: detailsView.nextUpEpisode ? (detailsView.nextUpEpisode.subtitle || detailsView.nextUpEpisode.title) : ""
                            font.pixelSize: 12
                            font.bold: true
                            color: "#ffffff"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: nextUpCardMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: detailsView.playRequested(detailsView.nextUpEpisode)
                    }
                }
            }

            // ==========================================
            // SEASONS SECTION (TV SHOW VIEW ONLY)
            // ==========================================
            ColumnLayout {
                visible: detailsView.isSeries && detailsView.seasonsList.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14

                Text {
                    text: "Seasons"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#ffffff"
                }

                ListView {
                    id: seasonsListView
                    Layout.fillWidth: true
                    Layout.preferredHeight: 220
                    orientation: ListView.Horizontal
                    spacing: 18
                    focus: true
                    model: detailsView.seasonsList

                    delegate: Rectangle {
                        id: seasonCard
                        width: 140
                        height: 210
                        radius: 12
                        color: activeFocus ? AppData.currentTheme.focusCard : (detailsView.activeSeason && detailsView.activeSeason.id === modelData.id ? "#0f172a" : "#090d16")
                        border.color: activeFocus ? AppData.currentTheme.accent : (detailsView.activeSeason && detailsView.activeSeason.id === modelData.id ? "#0284c7" : "#1e293b")
                        border.width: activeFocus ? 4 : 1
                        focus: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 8
                                color: "#020617"
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: modelData.posterUrl || detailsView.item.posterUrl
                                    fillMode: Image.PreserveAspectCrop
                                }

                                // Episode count badge (top right badge matching Screenshot #2)
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 4
                                    width: 22
                                    height: 22
                                    radius: 11
                                    color: "#0284c7"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.childCount ? String(modelData.childCount) : "10"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: modelData.title || "Season"
                                font.pixelSize: 13
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                seasonCard.forceActiveFocus()
                                detailsView.loadSeasonEpisodes(modelData)
                            }
                        }

                        Keys.onReturnPressed: detailsView.loadSeasonEpisodes(modelData)
                        Keys.onSpacePressed: detailsView.loadSeasonEpisodes(modelData)
                        Keys.onUpPressed: function(event) { playBtn.forceActiveFocus(); event.accepted = true }
                        Keys.onDownPressed: function(event) {
                            if (episodesListView.count > 0) episodesListView.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
            }

            // ==========================================
            // EPISODES SECTION (EPISODE SWIMLANE)
            // ==========================================
            ColumnLayout {
                visible: detailsView.episodesList.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: detailsView.isEpisode ? ("More from Season " + (detailsView.item.seasonNumber || "1")) : "Episodes"
                        font.pixelSize: 20
                        font.bold: true
                        color: "#ffffff"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: detailsView.episodesList.length + " Episodes"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: episodesListView
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250
                    orientation: ListView.Horizontal
                    spacing: 20
                    clip: false
                    focus: true

                    model: detailsView.episodesList

                    delegate: Item {
                        width: 270
                        height: 240
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) epCard.forceActiveFocus()
                        }

                        Rectangle {
                            id: epCard
                            anchors.fill: parent
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            focus: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 6

                                // Thumbnail Box with Centered Play Button Overlay
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.backdropUrl || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }

                                    // Play Overlay Icon Button (Clicking this directly plays the episode)
                                    Rectangle {
                                        id: playIconOverlay
                                        anchors.centerIn: parent
                                        width: 42
                                        height: 42
                                        radius: 21
                                        color: playMouse.containsMouse ? AppData.currentTheme.accent : "#cc0f172a"
                                        border.color: playMouse.containsMouse ? "#ffffff" : "transparent"
                                        border.width: 1

                                        Image {
                                            anchors.centerIn: parent
                                            width: 18
                                            height: 18
                                            source: "assets/icons/play.svg"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        MouseArea {
                                            id: playMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                detailsView.playRequested(modelData)
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: (modelData.episodeNumber ? (modelData.episodeNumber + ". ") : "") + (modelData.episodeName || modelData.title)
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: (modelData.premiereDate || "") + (modelData.duration ? (" • " + modelData.duration) : "")
                                    font.pixelSize: 11
                                    color: "#94a3b8"
                                    Layout.fillWidth: true
                                }
                            }

                            // Card MouseArea (Clicking card outside play icon opens Episode Details View)
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    episodesListView.currentIndex = index
                                    epCard.forceActiveFocus()
                                    detailsView.item = modelData
                                }
                            }

                            Keys.onReturnPressed: detailsView.item = modelData
                            Keys.onSpacePressed: detailsView.playRequested(modelData)
                            Keys.onUpPressed: function(event) {
                                if (seasonsListView.visible && seasonsListView.count > 0) seasonsListView.forceActiveFocus()
                                else playBtn.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }
                }
            }

            // ==========================================
            // CAST & CREW SECTION (Matches Screenshots)
            // ==========================================
            ColumnLayout {
                visible: detailsView.item && detailsView.item.people && detailsView.item.people.length > 0
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14

                Text {
                    text: "Cast & Crew"
                    font.pixelSize: 20
                    font.bold: true
                    color: "#ffffff"
                }

                ListView {
                    id: castListView
                    Layout.fillWidth: true
                    Layout.preferredHeight: 180
                    orientation: ListView.Horizontal
                    spacing: 18
                    clip: false
                    focus: true
                    model: detailsView.item ? detailsView.item.people : []

                    delegate: Item {
                        width: 110
                        height: 170

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 100
                                Layout.preferredHeight: 110
                                radius: 10
                                color: "#0f172a"
                                border.color: "#334155"
                                border.width: 1
                                clip: true
                                Layout.alignment: Qt.AlignHCenter

                                Image {
                                    anchors.fill: parent
                                    source: modelData.imageUrl || ""
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }

                            Text {
                                text: modelData.name || "Actor"
                                font.pixelSize: 12
                                font.bold: true
                                color: "#ffffff"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.role || "Cast"
                                font.pixelSize: 10
                                color: "#94a3b8"
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
