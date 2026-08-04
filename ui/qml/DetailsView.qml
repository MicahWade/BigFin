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
    property var lastFocusedItem: null

    function restoreFocus() {
        if (lastFocusedItem && lastFocusedItem.visible) {
            lastFocusedItem.forceActiveFocus()
            if (typeof ensureVisible === "function") ensureVisible(lastFocusedItem)
            return true
        }
        if (defaultFocusItem) {
            defaultFocusItem.forceActiveFocus()
            if (defaultFocusItem.currentItem) defaultFocusItem.currentItem.forceActiveFocus()
            return true
        }
        return false
    }

    function getItemType() {
        if (!item) return "Movie"
        var t = item.mediaType || item.type || item.Type || (item.rawData ? (item.rawData.Type || item.rawData.mediaType) : "")
        if (typeof t === "string") t = t.toLowerCase()
        if (t === "episode") return "Episode"
        if (item.seriesId || item.SeriesId || (item.rawData && item.rawData.SeriesId)) return "Episode"
        if (item.seasonId || item.SeasonId || (item.rawData && item.rawData.SeasonId)) return "Episode"
        if (t === "series" || t === "show" || t === "tvshow" || t === "folder") return "Series"
        if (item.seasonsEpisodesStr && item.seasonsEpisodesStr !== "") return "Series"
        if (item.childCount && item.childCount > 0) return "Series"
        if (item.recursiveItemCount && item.recursiveItemCount > 0) return "Series"
        if (item.seasonCount && item.seasonCount > 0) return "Series"
        if (item.episodeCount && item.episodeCount > 0) return "Series"
        return "Movie"
    }

    readonly property string itemType: getItemType()
    readonly property bool isEpisode: itemType === "Episode"
    readonly property bool isSeries: itemType === "Series"

    function getSeriesId() {
        if (!item) return ""
        var sid = item.id || item.Id || item.seriesId || item.SeriesId || (item.rawData ? (item.rawData.SeriesId || item.rawData.Id) : "")
        return sid || ""
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

    function getEpisodeSubtitle(ep) {
        if (!ep) return ""
        var sNum = ep.seasonNumber || 1
        var eNum = ep.episodeNumber || ""
        var codeStr = (sNum && eNum) ? ("S" + sNum + ":E" + eNum) : (ep.epCode || "")
        var durStr = ep.duration || "23m"
        
        var parts = []
        if (codeStr !== "") parts.push(codeStr)
        if (durStr !== "") parts.push(durStr)
        
        if (AppData.showEndsAtInSubtitle) {
            parts.push(getEndsAtString(durStr))
        }
        
        return parts.join(" • ")
    }

    property var seasonsList: []
    property var episodesList: []
    property var seasonsWithEpisodes: []
    property var nextUpEpisode: null
    property var activeSeason: null

    function ensureVisible(targetItem) {
        if (!targetItem) return
        var mapped = targetItem.mapToItem(mainDetailsColumn, 0, 0)
        var itemY = mapped.y
        var itemH = targetItem.height
        var viewH = mainFlickable.height
        if (viewH <= 0) return

        // Keep the selected row centered vertically in the viewport
        var targetY = (itemY + itemH / 2) - (viewH / 2)
        var maxY = Math.max(0, mainFlickable.contentHeight - viewH)
        mainFlickable.contentY = Math.max(0, Math.min(maxY, targetY))
    }

    function navigateDownFromHero() {
        if (seasonsRepeater && seasonsRepeater.count > 0) {
            var firstSeason = seasonsRepeater.itemAt(0)
            if (firstSeason && firstSeason.focusCurrentOrFirstCard) {
                firstSeason.focusCurrentOrFirstCard(0)
                return true
            }
        }
        if (castListView.visible && castListView.count > 0) {
            castListView.forceActiveFocus()
            if (castListView.currentItem) castListView.currentItem.forceActiveFocus()
            return true
        }
        return false
    }

    onItemChanged: loadData()
    onVisibleChanged: { if (visible) loadData() }

    function loadDemoSeasons() {
        var demoPoster = item ? (item.backdropUrl || item.posterUrl) : ""
        var s1Eps = [
            { id: "ep_1_1", seasonNumber: 1, episodeNumber: "1", episodeName: "The Merge, Part 1", title: "1. The Merge, Part 1", duration: "23m", rating: "8.9", overview: "One year after 'The Merge,' Ninja-fan Arin and his friend, Sora, risk everything to save the life of a hunted young dragon named Riyu.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: true },
            { id: "ep_1_2", seasonNumber: 1, episodeNumber: "2", episodeName: "The Merge, Part 2", title: "2. The Merge, Part 2", duration: "23m", rating: "8.3", overview: "Arin and Sora develop new powers that just might help them confront the dragon hunters. Can the Green Ninja teach them how to harness their abilities?", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: true },
            { id: "ep_1_3", seasonNumber: 1, episodeNumber: "3", episodeName: "Crossroads Carnival", title: "3. Crossroads Carnival", duration: "23m", rating: "7.8", overview: "On training day, Arin and Sora sneak out of the monastery to attend the Crossroads Carnival and uncover a villainous plot that tests their skills.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: true },
            { id: "ep_1_4", seasonNumber: 1, episodeNumber: "4", episodeName: "Beyond Madness", title: "4. Beyond Madness", duration: "23m", rating: "9.4", overview: "When the Bounty airship returns with no captain, Arin, Sora and Lloyd use clues to figure out what happened to Kai.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: true }
        ]
        var s2Eps = [
            { id: "ep_2_1", seasonNumber: 2, episodeNumber: "1", episodeName: "Rising Dragon", title: "1. Rising Dragon", duration: "23m", rating: "8.7", overview: "Arin learns the ancient Rising Dragon technique to combat new villains threatening the realm.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_2_2", seasonNumber: 2, episodeNumber: "2", episodeName: "Shattered Dreams", title: "2. Shattered Dreams", duration: "23m", rating: "8.5", overview: "The Ninja team ventures into the shadow realm to recover missing dragon artifacts.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_2_3", seasonNumber: 2, episodeNumber: "3", episodeName: "The Blood Moon", title: "3. The Blood Moon", duration: "23m", rating: "8.8", overview: "A rare lunar alignment empowers the wolf mask warriors as the ninja defend the temple.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_2_4", seasonNumber: 2, episodeNumber: "4", episodeName: "Dragon's Flame", title: "4. Dragon's Flame", duration: "23m", rating: "9.1", overview: "Riyu unlocks a powerful elemental surge to save the team from impending destruction.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false }
        ]
        var s3Eps = [
            { id: "ep_3_1", seasonNumber: 3, episodeNumber: "1", episodeName: "Uncharted Realms", title: "1. Uncharted Realms", duration: "23m", rating: "8.6", overview: "The Ninja set sail into undiscovered lands to track the source of the realm anomalies.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_3_2", seasonNumber: 3, episodeNumber: "2", episodeName: "Shadow of the Mask", title: "2. Shadow of the Mask", duration: "23m", rating: "8.4", overview: "An enigmatic warrior wearing a shatter-spin mask challenges Sora's mechanical genius.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_3_3", seasonNumber: 3, episodeNumber: "3", episodeName: "The Forbidden Scroll", title: "3. The Forbidden Scroll", duration: "23m", rating: "8.9", overview: "Arin deciphers an ancient manuscript revealing the origins of the dragon masters.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_3_4", seasonNumber: 3, episodeNumber: "4", episodeName: "Tournament of Sources", title: "4. Tournament of Sources", duration: "23m", rating: "9.3", overview: "The Ninja enter a legendary arena where elemental masters compete for supremacy.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false }
        ]
        var s4Eps = [
            { id: "ep_4_1", seasonNumber: 4, episodeNumber: "1", episodeName: "The Source Dragons", title: "1. The Source Dragons", duration: "23m", rating: "9.0", overview: "The ultimate trial begins as seven Source Dragons gather to restore balance.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_4_2", seasonNumber: 4, episodeNumber: "2", episodeName: "Shattered Realms", title: "2. Shattered Realms", duration: "23m", rating: "8.8", overview: "Reality fractures as the villains trigger their master plan.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_4_3", seasonNumber: 4, episodeNumber: "3", episodeName: "Legacy of Spinjitzu", title: "3. Legacy of Spinjitzu", duration: "23m", rating: "9.2", overview: "Arin and Sora combine Spinjitzu and tech for an unprecedented fusion attack.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false },
            { id: "ep_4_4", seasonNumber: 4, episodeNumber: "4", episodeName: "A New Dawn", title: "4. A New Dawn", duration: "24m", rating: "9.6", overview: "The epic season climax where new masters emerge to protect all merged realms.", backdropUrl: demoPoster, posterUrl: demoPoster, isPlayed: false }
        ]

        seasonsWithEpisodes = [
            { id: "s1", seasonNumber: 1, title: "Season 1", episodes: s1Eps, childCount: 4 },
            { id: "s2", seasonNumber: 2, title: "Season 2", episodes: s2Eps, childCount: 4 },
            { id: "s3", seasonNumber: 3, title: "Season 3", episodes: s3Eps, childCount: 4 },
            { id: "s4", seasonNumber: 4, title: "Season 4", episodes: s4Eps, childCount: 4 }
        ]
    }

    function groupEpisodesBySeason(allEps) {
        if (!allEps || allEps.length === 0) return []
        var seasonMap = {}
        var order = []
        for (var i = 0; i < allEps.length; i++) {
            var ep = allEps[i]
            var sNum = 1
            if (ep.seasonNumber !== undefined && ep.seasonNumber !== null && ep.seasonNumber !== "") {
                var p = parseInt(ep.seasonNumber)
                if (!isNaN(p)) sNum = p
            }
            var sKey = "s_" + sNum
            if (!seasonMap[sKey]) {
                seasonMap[sKey] = {
                    id: sKey,
                    seasonNumber: sNum,
                    title: sNum === 0 ? "Specials" : ("Season " + sNum),
                    episodes: [],
                    childCount: 0
                }
                order.push(sKey)
            }
            seasonMap[sKey].episodes.push(ep)
            seasonMap[sKey].childCount++
        }

        order.sort(function(a, b) {
            return seasonMap[a].seasonNumber - seasonMap[b].seasonNumber
        })

        var result = []
        for (var j = 0; j < order.length; j++) {
            var sObj = seasonMap[order[j]]
            sObj.episodes.sort(function(e1, e2) {
                var n1 = parseInt(e1.episodeNumber || e1.IndexNumber || 0)
                var n2 = parseInt(e2.episodeNumber || e2.IndexNumber || 0)
                return n1 - n2
            })
            result.push(sObj)
        }
        return result
    }

    function loadData() {
        seasonsList = []
        episodesList = []
        seasonsWithEpisodes = []
        nextUpEpisode = null
        activeSeason = null

        if (!item) return

        var resolvedType = getItemType()
        var isSeriesItem = (resolvedType === "Series")
        var isEpisodeItem = (resolvedType === "Episode")
        var sId = getSeriesId()
        console.log("[DETAILS] loadData. Item: " + (item ? item.title : "null") + " | Resolved Type: " + resolvedType + " | Series ID: " + sId)

        if (isSeriesItem) {
            if (sId !== "") {
                AppData.fetchNextUpForSeries(sId, function(nextEp) {
                    if (nextEp) nextUpEpisode = nextEp
                })

                // Primary: Fetch all episodes for the series directly from Jellyfin
                AppData.fetchEpisodes(sId, "", function(allEps) {
                    if (allEps && allEps.length > 0) {
                        console.log("[DETAILS] Successfully loaded " + allEps.length + " live Jellyfin episodes for series ID: " + sId)
                        episodesList = allEps
                        seasonsWithEpisodes = groupEpisodesBySeason(allEps)
                    } else {
                        console.log("[DETAILS] Primary fetchEpisodes returned 0 items. Trying fetchSeasons fallback...")
                        // Fallback: Fetch seasons first, then episodes per season
                        AppData.fetchSeasons(sId, function(seasons) {
                            if (seasons && seasons.length > 0) {
                                seasonsList = seasons
                                var list = []
                                var pendingCount = seasons.length
                                for (var i = 0; i < seasons.length; i++) {
                                    (function(sObj, idx) {
                                        AppData.fetchEpisodes(sId, sObj.id, function(eps) {
                                            list[idx] = {
                                                id: sObj.id,
                                                seasonNumber: sObj.seasonNumber || (idx + 1),
                                                title: sObj.title || ("Season " + (idx + 1)),
                                                episodes: (eps && eps.length > 0) ? eps : [],
                                                childCount: (eps && eps.length > 0) ? eps.length : (sObj.childCount || 0)
                                            }
                                            pendingCount--
                                            if (pendingCount <= 0) {
                                                var cleanList = []
                                                for (var k = 0; k < list.length; k++) {
                                                    if (list[k]) cleanList.push(list[k])
                                                }
                                                seasonsWithEpisodes = cleanList
                                            }
                                        })
                                    })(seasons[i], i)
                                }
                            } else {
                                console.log("[DETAILS] fetchSeasons returned 0 items. Loading demo seasons...")
                                loadDemoSeasons()
                            }
                        })
                    }
                })
            } else {
                console.log("[DETAILS] Series ID is empty. Loading demo seasons...")
                loadDemoSeasons()
            }
        } else if (isEpisodeItem && sId !== "") {
            var seasonIdToFetch = item.seasonId || ""
            AppData.fetchEpisodes(sId, seasonIdToFetch, function(episodes) {
                if (episodes && episodes.length > 0) {
                    seasonsWithEpisodes = groupEpisodesBySeason(episodes)
                } else {
                    seasonsWithEpisodes = []
                }
            })
        } else {
            seasonsWithEpisodes = []
        }
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainDetailsColumn.implicitHeight + 100
        clip: true

        Behavior on contentY {
            NumberAnimation { duration: 200; easing.type: "OutCubic" }
        }

        // Backdrop Ambient Image
        Image {
            anchors.fill: parent
            source: (detailsView.item && (detailsView.item.backdropUrl || detailsView.item.posterUrl)) ? (detailsView.item.backdropUrl || detailsView.item.posterUrl) : ""
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
                        source: (detailsView.item && (detailsView.item.posterUrl || detailsView.item.backdropUrl)) ? (detailsView.item.posterUrl || detailsView.item.backdropUrl) : ""
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
                                    var s = detailsView.item.seasonNumber !== "" ? detailsView.item.seasonNumber : "1"
                                    var e = detailsView.item.episodeNumber ? (detailsView.item.episodeNumber + ". ") : ""
                                    var name = detailsView.item.episodeName || detailsView.item.title
                                    return "Season " + s + " - " + e + name
                                } else if (detailsView.isSeries) {
                                    if (detailsView.item.seasonsEpisodesStr) return detailsView.item.seasonsEpisodesStr
                                    var sCount = detailsView.item.childCount || (detailsView.seasonsList ? detailsView.seasonsList.length : 0)
                                    var epCount = detailsView.item.recursiveItemCount || detailsView.item.episodeCount || 0
                                    var sText = sCount > 0 ? (sCount + (sCount === 1 ? " Season" : " Seasons")) : ""
                                    var eText = epCount > 0 ? (epCount + (epCount === 1 ? " Episode" : " Episodes")) : ""
                                    if (sText && eText) return sText + " • " + eText
                                    if (sText) return sText
                                    if (eText) return eText
                                }
                                return ""
                            }
                            font.pixelSize: 18
                            font.bold: true
                            color: "#e2e8f0"
                            visible: detailsView.isEpisode || detailsView.isSeries
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
                            onActiveFocusChanged: { if (activeFocus) detailsView.lastFocusedItem = playBtn }

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
                            Keys.onDownPressed: function(event) { detailsView.navigateDownFromHero(); event.accepted = true }
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
                            Keys.onUpPressed: function(event) { backBtn.forceActiveFocus(); event.accepted = true }
                            Keys.onDownPressed: function(event) { detailsView.navigateDownFromHero(); event.accepted = true }
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
                            Keys.onUpPressed: function(event) { backBtn.forceActiveFocus(); event.accepted = true }
                            Keys.onDownPressed: function(event) { detailsView.navigateDownFromHero(); event.accepted = true }
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
                            Keys.onUpPressed: function(event) { backBtn.forceActiveFocus(); event.accepted = true }
                            Keys.onDownPressed: function(event) { detailsView.navigateDownFromHero(); event.accepted = true }
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
                            visible: !!(detailsView.item && detailsView.item.tags)
                            spacing: 10
                            Text { text: "Tags:"; font.pixelSize: 13; font.bold: true; color: "#94a3b8" }
                            Text {
                                text: (detailsView.item && detailsView.item.tags) ? detailsView.item.tags : ""
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
                                visible: !!(detailsView.item && detailsView.item.studio)
                                spacing: 8
                                Text { text: "Studio:"; font.pixelSize: 13; font.bold: true; color: "#94a3b8" }
                                Text {
                                    text: (detailsView.item && detailsView.item.studio) ? detailsView.item.studio : ""
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
            // SEASONS SWIMLANES (MATCHES USER SCREENSHOT)
            // ==========================================
            Repeater {
                id: seasonsRepeater
                model: detailsView.isSeries ? detailsView.seasonsWithEpisodes : []

                delegate: ColumnLayout {
                    id: seasonSwimlaneCol
                    property int seasonRowIndex: index
                    Layout.fillWidth: true
                    Layout.leftMargin: 48
                    Layout.rightMargin: 48
                    spacing: 14

                    function focusFirstCard() {
                        seasonEpListView.forceActiveFocus()
                        if (seasonEpListView.currentItem) {
                            seasonEpListView.currentItem.forceActiveFocus()
                        }
                    }

                    function focusCurrentOrFirstCard(idx) {
                        seasonEpListView.forceActiveFocus()
                        var targetIndex = (AppData && AppData.seasonNavGoesToStart) ? 0 : Math.min(idx, seasonEpListView.count - 1)
                        if (targetIndex >= 0 && targetIndex < seasonEpListView.count) {
                            seasonEpListView.currentIndex = targetIndex
                        }
                        if (seasonEpListView.currentItem) {
                            seasonEpListView.currentItem.forceActiveFocus()
                        }
                    }

                    // Season Header Title & Episode Count
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: modelData.seasonNumber ? ("Season " + modelData.seasonNumber) : (modelData.title || "Season")
                            font.pixelSize: 22
                            font.bold: true
                            color: "#ffffff"
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: (modelData.episodes ? modelData.episodes.length : (modelData.childCount || 0)) + " Episodes"
                            font.pixelSize: 13
                            color: "#94a3b8"
                        }
                    }

                    // Horizontal Episode Swimlane
                    ListView {
                        id: seasonEpListView
                        Layout.fillWidth: true
                        Layout.preferredHeight: 250
                        orientation: ListView.Horizontal
                        spacing: 20
                        clip: false
                        focus: true
                        model: modelData.episodes || []
                        highlightRangeMode: ListView.ApplyRange
                        preferredHighlightBegin: 0
                        preferredHighlightEnd: width - 280
                        highlightMoveDuration: 75
                        highlightResizeDuration: 75
                        maximumFlickVelocity: 6000
                        flickDeceleration: 8000

                        delegate: Rectangle {
                            id: epSwimCard
                            width: 280
                            height: 240
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            scale: activeFocus ? 1.03 : 1.0
                            focus: true

                            Behavior on scale { NumberAnimation { duration: 120; easing.type: "OutCubic" } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    detailsView.lastFocusedItem = epSwimCard
                                    seasonEpListView.currentIndex = index
                                    detailsView.ensureVisible(epSwimCard)
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // 16:9 Thumbnail Image Card
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.thumbUrl || modelData.backdropUrl || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }

                                    // Centered Play Button Overlay Button
                                    Rectangle {
                                        id: centerPlayBtn
                                        anchors.centerIn: parent
                                        width: 46
                                        height: 46
                                        radius: 23
                                        color: centerPlayMouse.containsMouse ? AppData.currentTheme.accent : "#cc0f172a"
                                        border.color: "#ffffff"
                                        border.width: 1
                                        z: 10

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: "assets/icons/play.svg"
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        MouseArea {
                                            id: centerPlayMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: {
                                                detailsView.playRequested(modelData)
                                            }
                                        }
                                    }

                                    // Watched Checkmark Badge (top right)
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: "#0284c7"
                                        visible: modelData.isPlayed || false

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✓"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                    }
                                }

                                Text {
                                    text: (modelData.episodeNumber ? (modelData.episodeNumber + ". ") : "") + (modelData.episodeName || modelData.title)
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: detailsView.getEpisodeSubtitle(modelData)
                                    font.pixelSize: 12
                                    color: "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                onClicked: {
                                    detailsView.item = modelData
                                }
                            }

                            Keys.onReturnPressed: detailsView.item = modelData
                            Keys.onSpacePressed: detailsView.playRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                var epIdx = index
                                var rIdx = seasonSwimlaneCol.seasonRowIndex
                                if (rIdx === 0) {
                                    playBtn.forceActiveFocus()
                                    mainFlickable.contentY = 0
                                } else if (rIdx > 0) {
                                    var prevItem = seasonsRepeater.itemAt(rIdx - 1)
                                    if (prevItem && prevItem.focusCurrentOrFirstCard) {
                                        prevItem.focusCurrentOrFirstCard(epIdx)
                                    }
                                }
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                var epIdx = index
                                var rIdx = seasonSwimlaneCol.seasonRowIndex
                                if (rIdx < seasonsRepeater.count - 1) {
                                    var nextItem = seasonsRepeater.itemAt(rIdx + 1)
                                    if (nextItem && nextItem.focusCurrentOrFirstCard) {
                                        nextItem.focusCurrentOrFirstCard(epIdx)
                                    }
                                } else if (castListView.visible && castListView.count > 0) {
                                    castListView.forceActiveFocus()
                                    if (castListView.currentItem) castListView.currentItem.forceActiveFocus()
                                }
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    detailsView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    seasonEpListView.currentIndex = index - 1
                                    if (seasonEpListView.currentItem) seasonEpListView.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < seasonEpListView.count - 1) {
                                    seasonEpListView.currentIndex = index + 1
                                    if (seasonEpListView.currentItem) seasonEpListView.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                visible: !!(detailsView.item && detailsView.item.people && detailsView.item.people.length > 0)
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
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: width - 120
                    highlightMoveDuration: 75
                    highlightResizeDuration: 75
                    maximumFlickVelocity: 6000
                    flickDeceleration: 8000

                    delegate: Item {
                        id: castDelegateItem
                        width: 110
                        height: 170
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) castCard.forceActiveFocus()
                        }

                        Rectangle {
                            id: castCard
                            anchors.fill: parent
                            radius: 10
                            color: activeFocus ? AppData.currentTheme.focusCard : "transparent"
                            border.color: activeFocus ? AppData.currentTheme.accent : "transparent"
                            border.width: activeFocus ? 2 : 0
                            focus: true

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    detailsView.lastFocusedItem = castCard
                                    castListView.currentIndex = index
                                }
                            }

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

                            Keys.onUpPressed: function(event) {
                                if (episodesListView.visible && detailsView.episodesList.length > 0) {
                                    episodesListView.forceActiveFocus()
                                    if (episodesListView.currentItem) episodesListView.currentItem.forceActiveFocus()
                                } else if (seasonsListView.visible && detailsView.seasonsList.length > 0) {
                                    seasonsListView.forceActiveFocus()
                                    if (seasonsListView.currentItem) seasonsListView.currentItem.forceActiveFocus()
                                } else {
                                    playBtn.forceActiveFocus()
                                }
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    detailsView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    castListView.currentIndex = index - 1
                                    if (castListView.currentItem) castListView.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < castListView.count - 1) {
                                    castListView.currentIndex = index + 1
                                    if (castListView.currentItem) castListView.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
