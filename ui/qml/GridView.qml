import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: gridView
    anchors.fill: parent

    signal itemSelected(var item)
    signal requestSidebarFocus()

    property string categoryFilter: "movies"
    property string musicSubFilter: AppData.activeMusicSubFilter ? AppData.activeMusicSubFilter : "songs"
    property bool playlistsExpanded: true

    onMusicSubFilterChanged: {
        if (AppData.activeMusicSubFilter !== musicSubFilter) {
            AppData.activeMusicSubFilter = musicSubFilter
        }
    }

    property alias mediaGridView: mediaGridView
    property int savedIndex: -1

    onSavedIndexChanged: {
        applySavedSpot()
    }

    function applySavedSpot() {
        if (savedIndex >= 0 && mediaGridView && mediaGridView.count > 0) {
            var targetIdx = Math.min(savedIndex, mediaGridView.count - 1)
            mediaGridView.currentIndex = targetIdx
            mediaGridView.positionViewAtIndex(targetIdx, GridView.Contain)
        }
    }

    Connections {
        target: mediaGridView
        function onCountChanged() {
            if (gridView.savedIndex >= 0) {
                gridView.applySavedSpot()
            }
        }
    }

    function restoreFocus() {
        applySavedSpot()
        if (mediaGridView && mediaGridView.count > 0) {
            var targetIdx = savedIndex >= 0 ? Math.min(savedIndex, mediaGridView.count - 1) : (mediaGridView.currentIndex >= 0 ? mediaGridView.currentIndex : 0)
            mediaGridView.currentIndex = targetIdx
            mediaGridView.positionViewAtIndex(targetIdx, GridView.Contain)
            mediaGridView.forceActiveFocus()
            if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
            return true
        } else if (categoryFilter === "music" && musicSubTabBarRepeater) {
            var activeIdx = getMusicSubTabIndex(musicSubFilter)
            var targetTab = musicSubTabBarRepeater.itemAt(activeIdx)
            if (targetTab) {
                targetTab.forceActiveFocus()
                return true
            }
        }
        return false
    }

    function getMusicSubTabIndex(filter) {
        var opts = ["artists", "playlists", "songs"]
        var idx = opts.indexOf(filter)
        return idx >= 0 ? idx : 0
    }

    onCategoryFilterChanged: {
        playlistsExpanded = true
    }

    property var playlistsList: {
        var items = []
        if (AppData.playlistsList && AppData.playlistsList.length > 0) {
            for (var i = 0; i < AppData.playlistsList.length; i++) {
                var item = AppData.playlistsList[i]
                var pType = (item.playlistType || item.PlaylistMediaType || item.MediaType || "").toLowerCase()
                var mType = (item.mediaType || item.Type || "").toLowerCase()
                if (mType === "playlist" || pType === "playlist" || pType === "audio" || pType === "music" || pType !== "movie") {
                    items.push(item)
                }
            }
        }
        if (items.length > 0) return items

        var rawMusic = AppData.musicList.length > 0 ? AppData.musicList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Playlist" || i.Type === "Playlist" })
        var pl = []
        for (var k = 0; k < rawMusic.length; k++) {
            if (rawMusic[k].mediaType === "Playlist" || rawMusic[k].Type === "Playlist") {
                pl.push(rawMusic[k])
            }
        }
        if (pl.length > 0) return pl
        if (AppData.isConnectedToLiveServer) return []
        return [
            { id: "pl_s1", title: "Family Playlist", mediaType: "Playlist", playlistType: "Audio", subtitle: "12 Songs • Playlist", poster1: "assets/posters/american_pie.svg", poster2: "assets/posters/sabaton.svg", poster3: "assets/posters/bladerunner.svg", poster4: "assets/posters/interstellar.svg" },
            { id: "pl_s2", title: "My Song List", mediaType: "Playlist", playlistType: "Audio", subtitle: "8 Songs • Playlist", poster1: "assets/posters/sabaton.svg", poster2: "assets/posters/dune2.svg", poster3: "assets/posters/mandalorian.svg", poster4: "assets/posters/breakingbad.svg" }
        ]
    }
    property alias defaultFocusItem: defaultFocusScope

    Item {
        id: defaultFocusScope
        property var currentItem: mediaGridView.currentItem
        property int currentIndex: mediaGridView.currentIndex
        property int count: mediaGridView.count

        onActiveFocusChanged: {
            if (activeFocus) {
                mediaGridView.forceActiveFocus()
                if (mediaGridView.currentIndex < 0 && mediaGridView.count > 0) mediaGridView.currentIndex = 0
                if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 24
        spacing: 20

        // Filter Header Section
        RowLayout {
            Layout.fillWidth: true
            spacing: 20

            Text {
                text: categoryFilter === "movies" ? "Movies Library" : (categoryFilter === "tvshows" ? "Shows Library" : (categoryFilter === "music" ? "Music Library" : "Favorites"))
                font.pixelSize: 28
                font.bold: true
                color: "#ffffff"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: mediaGridView.count + " Items"
                font.pixelSize: 14
                color: "#94a3b8"
            }
        }

        // Music Sub-Category Filter Bar (Matches Official Jellyfin UI in Screenshot)
        RowLayout {
            id: musicSubTabBar
            Layout.fillWidth: true
            spacing: 20
            visible: categoryFilter === "music"

            Repeater {
                id: musicSubTabBarRepeater
                model: [
                    { id: "artists", name: "Artists" },
                    { id: "playlists", name: "Playlists" },
                    { id: "songs", name: "Songs" }
                ]

                delegate: Rectangle {
                    id: subTabBtn
                    height: 52
                    radius: 12
                    implicitWidth: subTabText.implicitWidth + 48
                    color: (gridView.musicSubFilter === modelData.id) ? (subTabBtn.activeFocus ? "#8b5cf6" : "#7c3aed") : (subTabBtn.activeFocus ? "#312e81" : "#1e1b4b")
                    border.color: subTabBtn.activeFocus ? "#ffffff" : ((gridView.musicSubFilter === modelData.id) ? "#a855f7" : "#3730a3")
                    border.width: subTabBtn.activeFocus ? 3 : 1
                    focus: true

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    Text {
                        id: subTabText
                        anchors.centerIn: parent
                        text: modelData.name
                        font.pixelSize: 18
                        font.bold: true
                        color: (gridView.musicSubFilter === modelData.id || subTabBtn.activeFocus) ? "#ffffff" : "#a5b4fc"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            gridView.musicSubFilter = modelData.id
                            AppData.activeMusicSubFilter = modelData.id
                            subTabBtn.forceActiveFocus()
                        }
                    }

                    Keys.onReturnPressed: { gridView.musicSubFilter = modelData.id; AppData.activeMusicSubFilter = modelData.id; subTabBtn.forceActiveFocus() }
                    Keys.onEnterPressed: { gridView.musicSubFilter = modelData.id; AppData.activeMusicSubFilter = modelData.id; subTabBtn.forceActiveFocus() }
                    Keys.onSelectPressed: { gridView.musicSubFilter = modelData.id; AppData.activeMusicSubFilter = modelData.id; subTabBtn.forceActiveFocus() }
                    Keys.onSpacePressed: { gridView.musicSubFilter = modelData.id; AppData.activeMusicSubFilter = modelData.id; subTabBtn.forceActiveFocus() }

                    Keys.onLeftPressed: function(event) {
                        if (index > 0) {
                            var prev = musicSubTabBarRepeater.itemAt(index - 1)
                            if (prev) prev.forceActiveFocus()
                        } else {
                            gridView.requestSidebarFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onRightPressed: function(event) {
                        if (index < musicSubTabBarRepeater.count - 1) {
                            var next = musicSubTabBarRepeater.itemAt(index + 1)
                            if (next) next.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onUpPressed: function(event) {
                        gridView.requestSidebarFocus()
                        event.accepted = true
                    }

                    Keys.onDownPressed: function(event) {
                        mediaGridView.forceActiveFocus()
                        if (mediaGridView.currentIndex < 0 && mediaGridView.count > 0) mediaGridView.currentIndex = 0
                        if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // Clean Flat Media Grid
        GridView {
            id: mediaGridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 210
            cellHeight: categoryFilter === "music" ? 260 : 345
            clip: true
            focus: true

            onActiveFocusChanged: {
                if (activeFocus) {
                    if (currentIndex < 0 && count > 0) currentIndex = 0
                    if (currentItem) currentItem.forceActiveFocus()
                }
            }

            Keys.onLeftPressed: function(event) {
                var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                if (currentIndex <= 0 || columns <= 0 || currentIndex % columns === 0) {
                    gridView.requestSidebarFocus()
                } else {
                    currentIndex = currentIndex - 1
                    if (currentItem) currentItem.forceActiveFocus()
                }
                event.accepted = true
            }

            Keys.onUpPressed: function(event) {
                var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                if (columns <= 0) columns = 1
                if (currentIndex < columns) {
                    if (categoryFilter === "music") {
                        var activeIdx = gridView.getMusicSubTabIndex(gridView.musicSubFilter)
                        var targetTab = musicSubTabBarRepeater.itemAt(activeIdx)
                        if (targetTab) {
                            targetTab.forceActiveFocus()
                        } else {
                            gridView.requestSidebarFocus()
                        }
                    } else {
                        gridView.requestSidebarFocus()
                    }
                } else {
                    var targetIdx = currentIndex - columns
                    if (targetIdx >= 0) {
                        mediaGridView.currentIndex = targetIdx
                        if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                    }
                }
                event.accepted = true
            }

            model: {
                if (categoryFilter === "movies") {
                    return AppData.moviesList.length > 0 ? AppData.moviesList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Movie" || i.mediaType === "movie" })
                } else if (categoryFilter === "tvshows") {
                    return AppData.tvShowsList.length > 0 ? AppData.tvShowsList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Series" || i.mediaType === "series" || i.mediaType === "TvProgram" })
                } else if (categoryFilter === "music") {
                    if (musicSubFilter === "playlists") {
                        return gridView.playlistsList
                    } else if (musicSubFilter === "artists") {
                        return AppData.artistsList && AppData.artistsList.length > 0 ? AppData.artistsList : AppData.musicList.filter(function(a){ return a.mediaType === "MusicArtist" || a.Type === "MusicArtist" })
                    } else if (musicSubFilter === "songs") {
                        var rawMusicS = AppData.musicList.length > 0 ? AppData.musicList : AppData.mediaGrid
                        var songsOnly = []
                        for (var s = 0; s < rawMusicS.length; s++) {
                            if (rawMusicS[s].mediaType === "Audio" || rawMusicS[s].Type === "Audio" || rawMusicS[s].mediaType === "MusicTrack") {
                                songsOnly.push(rawMusicS[s])
                            }
                        }
                        return songsOnly.length > 0 ? songsOnly : rawMusicS
                    } else {
                        return AppData.artistsList && AppData.artistsList.length > 0 ? AppData.artistsList : gridView.playlistsList
                    }
                } else if (categoryFilter === "favorites") {
                    return AppData.favoritesList.length > 0 ? AppData.favoritesList : AppData.mediaGrid.filter(function(i){ return i.isFavorite })
                }
                return AppData.mediaGrid
            }

            delegate: Item {
                width: mediaGridView.cellWidth
                height: mediaGridView.cellHeight
                focus: true

                property bool isEpisodeItem: (modelData.mediaType === "Episode")
                property bool isMusicItem: (categoryFilter === "music" || modelData.mediaType === "MusicAlbum" || modelData.mediaType === "Playlist" || modelData.mediaType === "Audio" || modelData.mediaType === "MusicArtist" || modelData.Type === "Playlist" || modelData.Type === "MusicAlbum")
                property bool isShowItem: (categoryFilter === "tvshows" || modelData.mediaType === "Series" || modelData.mediaType === "series" || modelData.mediaType === "Episode" || modelData.mediaType === "TvProgram")

                onActiveFocusChanged: {
                    if (activeFocus) {
                        gridCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: gridCard
                    width: isEpisodeItem ? 275 : 195
                    height: isMusicItem ? 245 : (isEpisodeItem ? 235 : 330)
                    anchors.centerIn: parent
                    radius: 12
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    scale: activeFocus ? 1.03 : 1.0
                    focus: true

                    Behavior on scale { NumberAnimation { duration: 120; easing.type: "OutCubic" } }
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mediaGridView.currentIndex = index
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        // Thumbnail Container (1:1 Square for Music, 16:9 for Episodes, 2:3 Poster for Shows & Movies)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: isMusicItem ? 175 : undefined
                            Layout.fillHeight: !isMusicItem
                            radius: 8
                            color: "#020617"
                            clip: true

                            // 2x2 Quadrant Collage for Playlists (Matches Official Jellyfin UI in Screenshot)
                            Item {
                                anchors.fill: parent
                                visible: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") && (modelData.poster1 && modelData.poster2)

                                Grid {
                                    anchors.fill: parent
                                    columns: 2
                                    rows: 2
                                    spacing: 1

                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster1 || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster2 || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster3 || modelData.poster1 || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster4 || modelData.poster2 || modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                }
                            }

                            // Single Poster / Image for regular items & Jellyfin API playlists
                            Image {
                                id: artistImg
                                anchors.fill: parent
                                visible: !((modelData.mediaType === "Playlist" || modelData.Type === "Playlist") && (modelData.poster1 && modelData.poster2)) && !((modelData.mediaType === "MusicArtist" || modelData.Type === "MusicArtist") && (!modelData.posterUrl || modelData.posterUrl === ""))
                                source: isEpisodeItem ? (modelData.thumbUrl || modelData.backdropUrl || modelData.posterUrl) : modelData.posterUrl
                                fillMode: isEpisodeItem ? Image.PreserveAspectCrop : (isMusicItem ? Image.PreserveAspectCrop : Image.PreserveAspectFit)
                                verticalAlignment: Image.AlignVCenter
                                horizontalAlignment: Image.AlignHCenter
                                smooth: true
                                asynchronous: true
                                cache: true
                            }

                            // Fallback Silhouette Tile for Artists without Photo (Matches Official Jellyfin UI in Screenshot)
                            Rectangle {
                                anchors.fill: parent
                                visible: (modelData.mediaType === "MusicArtist" || modelData.Type === "MusicArtist") && (artistImg.status !== Image.Ready || !modelData.posterUrl || modelData.posterUrl === "")
                                color: {
                                    var colors = ["#7c3aed", "#6366f1", "#059669", "#d97706", "#dc2626", "#4f46e5", "#0d9488"]
                                    var hash = 0
                                    var str = modelData.title || "Artist"
                                    for (var c = 0; c < str.length; c++) hash = str.charCodeAt(c) + ((hash << 5) - hash)
                                    return colors[Math.abs(hash) % colors.length]
                                }

                                Item {
                                    anchors.centerIn: parent
                                    width: 70
                                    height: 70

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 6
                                        width: 28
                                        height: 28
                                        radius: 14
                                        color: "#ffffff"
                                    }

                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 38
                                        width: 52
                                        height: 30
                                        radius: 15
                                        color: "#ffffff"
                                    }
                                }
                            }

                            // Centered Play Button Overlay for TV Episodes
                            Rectangle {
                                id: showPlayOverlay
                                anchors.centerIn: parent
                                width: 46
                                height: 46
                                radius: 23
                                color: "#cc0f172a"
                                border.color: "#ffffff"
                                border.width: 1
                                visible: isEpisodeItem

                                Image {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "assets/icons/play.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            // Watched Checkmark Badge at Top Right
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 24
                                height: 24
                                radius: 12
                                color: "#7c3aed"
                                visible: isShowItem && (modelData.isPlayed || false)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            // Rating / Playlist Badge
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? 72 : 44
                                height: 22
                                radius: 4
                                color: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? "#cc6366f1" : "#cc0f172a"
                                visible: !isShowItem && ((modelData.mediaType === "Playlist" || modelData.Type === "Playlist") || AppData.isRatingVisible(modelData))

                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? "PLAYLIST" : ("★ " + modelData.rating)
                                    font.pixelSize: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? 10 : 11
                                    font.bold: true
                                    color: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? "#ffffff" : "#fbbf24"
                                }
                            }
                        }

                        Text {
                            text: isShowItem ? ((modelData.episodeNumber ? (modelData.episodeNumber + ". ") : "") + (modelData.episodeName || modelData.title)) : modelData.title
                            font.pixelSize: 14
                            font.bold: true
                            color: gridCard.activeFocus ? "#ffffff" : "#e2e8f0"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? Text.AlignHCenter : Text.AlignLeft
                        }

                        Text {
                            text: isShowItem ? (modelData.seasonsEpisodesStr || modelData.subtitle || (modelData.year + " • " + modelData.duration)) : ((modelData.mediaType === "MusicArtist" || modelData.Type === "MusicArtist") ? (modelData.songs && modelData.songs.length > 0 ? (modelData.songs.length + " Songs") : (modelData.subtitle && modelData.subtitle !== "Artist" && modelData.subtitle !== "Music Artist" ? modelData.subtitle : "Songs")) : (modelData.subtitle || (modelData.year ? (modelData.year + " • " + modelData.duration) : "Music")))
                            font.pixelSize: 12
                            color: gridCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            horizontalAlignment: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? Text.AlignHCenter : Text.AlignLeft
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            mediaGridView.currentIndex = index
                            gridCard.forceActiveFocus()
                            gridView.itemSelected(modelData)
                        }
                    }

                    Keys.onReturnPressed: gridView.itemSelected(modelData)
                    Keys.onSpacePressed: gridView.itemSelected(modelData)

                    Keys.onLeftPressed: function(event) {
                        var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                        if (index <= 0 || columns <= 0 || index % columns === 0) {
                            gridView.requestSidebarFocus()
                        } else {
                            mediaGridView.currentIndex = index - 1
                            if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onUpPressed: function(event) {
                        var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                        if (columns <= 0) columns = 1
                        if (index < columns) {
                            if (categoryFilter === "music") {
                                var activeIdx = gridView.getMusicSubTabIndex(gridView.musicSubFilter)
                                var targetTab = musicSubTabBarRepeater.itemAt(activeIdx)
                                if (!targetTab) targetTab = musicSubTabBarRepeater.itemAt(0)
                                if (targetTab) {
                                    targetTab.forceActiveFocus()
                                } else {
                                    gridView.requestSidebarFocus()
                                }
                            } else {
                                gridView.requestSidebarFocus()
                            }
                        } else {
                            var targetIdx = index - columns
                            if (targetIdx >= 0) {
                                mediaGridView.currentIndex = targetIdx
                                if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                            }
                        }
                        event.accepted = true
                    }

                    Keys.onDownPressed: function(event) {
                        var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                        if (columns <= 0) columns = 1
                        if (index + columns < mediaGridView.count) {
                            mediaGridView.currentIndex = index + columns
                            if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                        } else if (index < mediaGridView.count - 1) {
                            mediaGridView.currentIndex = mediaGridView.count - 1
                            if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    Keys.onRightPressed: function(event) {
                        if (index < mediaGridView.count - 1) {
                            mediaGridView.currentIndex = index + 1
                            if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }
                }
            }
        }

        // Empty State / Connection Error Placeholder
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignCenter
            spacing: 16
            visible: mediaGridView.count === 0

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 64
                height: 64
                radius: 32
                color: AppData.isConnectedToLiveServer ? "#0f172a" : "#3f1212"
                border.color: AppData.isConnectedToLiveServer ? "#334155" : "#ef4444"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: AppData.isConnectedToLiveServer ? "i" : "!"
                    font.pixelSize: 28
                    font.bold: true
                    color: AppData.isConnectedToLiveServer ? "#94a3b8" : "#ef4444"
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: AppData.isConnectedToLiveServer ? "No items found in this library category." : "Not Connected to Jellyfin Server"
                font.pixelSize: 20
                font.bold: true
                color: "#ffffff"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: AppData.isConnectedToLiveServer ? "Check your Jellyfin server library or sync state." : (AppData.connectionError ? AppData.connectionError : "Unable to reach server.")
                font.pixelSize: 14
                color: AppData.isConnectedToLiveServer ? "#94a3b8" : "#fca5a5"
                horizontalAlignment: Text.AlignHCenter
                Layout.maximumWidth: 500
                wrapMode: Text.WordWrap
            }
        }
    }
}
