import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: gridView
    anchors.fill: parent

    signal itemSelected(var item)
    signal requestSidebarFocus()

    property string categoryFilter: "movies"
    property bool playlistsExpanded: true

    onCategoryFilterChanged: {
        playlistsExpanded = true
    }

    property var playlistsList: {
        if (AppData.playlistsList && AppData.playlistsList.length > 0) return AppData.playlistsList
        var rawMusic = AppData.musicList.length > 0 ? AppData.musicList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Playlist" || i.Type === "Playlist" })
        var pl = []
        for (var i = 0; i < rawMusic.length; i++) {
            if (rawMusic[i].mediaType === "Playlist" || rawMusic[i].Type === "Playlist") {
                pl.push(rawMusic[i])
            }
        }
        if (pl.length > 0) return pl
        return [
            { id: "pl1", title: "Family Playlist", mediaType: "Playlist", subtitle: "Playlist", posterUrl: "assets/posters/american_pie.svg" },
            { id: "pl2", title: "My Song List", mediaType: "Playlist", subtitle: "Playlist", posterUrl: "assets/posters/sabaton.svg" }
        ]
    }
    property alias defaultFocusItem: defaultFocusScope

    Item {
        id: defaultFocusScope
        property var currentItem: (categoryFilter === "music" && playlistsExpanded && playlistsListView.count > 0) ? playlistsListView.currentItem : mediaGridView.currentItem
        property int currentIndex: (categoryFilter === "music" && playlistsExpanded && playlistsListView.count > 0) ? playlistsListView.currentIndex : mediaGridView.currentIndex
        property int count: (categoryFilter === "music" && playlistsExpanded && playlistsListView.count > 0) ? playlistsListView.count : mediaGridView.count

        onActiveFocusChanged: {
            if (activeFocus) {
                if (categoryFilter === "music" && playlistsExpanded && playlistsListView.count > 0) {
                    playlistsListView.forceActiveFocus()
                    if (playlistsListView.currentItem) playlistsListView.currentItem.forceActiveFocus()
                } else {
                    mediaGridView.forceActiveFocus()
                    if (mediaGridView.currentIndex < 0 && mediaGridView.count > 0) mediaGridView.currentIndex = 0
                    if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                }
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
                text: (categoryFilter === "music" ? ((playlistsExpanded ? playlistsListView.count : 0) + mediaGridView.count) : mediaGridView.count) + " Items"
                font.pixelSize: 14
                color: "#94a3b8"
            }
        }

        // Dedicated Playlists Row (Displayed at the top of Music Tab)
        ColumnLayout {
            id: playlistsContainer
            Layout.fillWidth: true
            spacing: 12
            visible: categoryFilter === "music" && playlistsExpanded && gridView.playlistsList && gridView.playlistsList.length > 0

            Text {
                text: "Playlists"
                font.pixelSize: 20
                font.bold: true
                color: playlistsListView.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
            }

            ListView {
                id: playlistsListView
                Layout.fillWidth: true
                Layout.preferredHeight: 240
                orientation: ListView.Horizontal
                spacing: 20
                clip: false
                focus: true
                keyNavigationWraps: false

                model: gridView.playlistsList

                onActiveFocusChanged: {
                    if (activeFocus && currentItem) {
                        currentItem.forceActiveFocus()
                    }
                }

                delegate: Item {
                    width: 180
                    height: 230
                    focus: true

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            plCard.forceActiveFocus()
                        }
                    }

                    Rectangle {
                        id: plCard
                        width: 170
                        height: 220
                        anchors.centerIn: parent
                        radius: 12
                        color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                        border.color: activeFocus ? AppData.currentTheme.accent : "#6366f1"
                        border.width: activeFocus ? 4 : 1
                        focus: true

                        Behavior on border.color { ColorAnimation { duration: 120 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                playlistsListView.currentIndex = index
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 140
                                radius: 8
                                color: "#020617"
                                clip: true

                                Grid {
                                    anchors.fill: parent
                                    rows: 2
                                    columns: 2
                                    spacing: 1

                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster1 || modelData.posterUrl || "assets/posters/american_pie.svg"
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster2 || modelData.posterUrl || "assets/posters/sabaton.svg"
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster3 || modelData.posterUrl || "assets/posters/bladerunner.svg"
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                    Image {
                                        width: parent.width / 2 - 0.5
                                        height: parent.height / 2 - 0.5
                                        source: modelData.poster4 || modelData.posterUrl || "assets/posters/interstellar.svg"
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                    }
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 6
                                    width: 64
                                    height: 20
                                    radius: 4
                                    color: "#cc6366f1"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "PLAYLIST"
                                        font.pixelSize: 9
                                        font.bold: true
                                        color: "#ffffff"
                                    }
                                }
                            }

                            Text {
                                text: modelData.title
                                font.pixelSize: 14
                                font.bold: true
                                color: plCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: modelData.subtitle || "Playlist"
                                font.pixelSize: 11
                                color: plCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                playlistsListView.currentIndex = index
                                plCard.forceActiveFocus()
                                gridView.itemSelected(modelData)
                            }
                        }

                        Keys.onReturnPressed: gridView.itemSelected(modelData)
                        Keys.onSpacePressed: gridView.itemSelected(modelData)

                        Keys.onLeftPressed: function(event) {
                            if (index <= 0) {
                                gridView.requestSidebarFocus()
                            } else if (index > 0) {
                                playlistsListView.currentIndex = index - 1
                                if (playlistsListView.currentItem) playlistsListView.currentItem.forceActiveFocus()
                            }
                            event.accepted = true
                        }

                        Keys.onRightPressed: function(event) {
                            if (index < playlistsListView.count - 1) {
                                playlistsListView.currentIndex = index + 1
                                if (playlistsListView.currentItem) playlistsListView.currentItem.forceActiveFocus()
                            }
                            event.accepted = true
                        }

                        Keys.onUpPressed: function(event) {
                            gridView.requestSidebarFocus()
                            event.accepted = true
                        }

                        Keys.onDownPressed: function(event) {
                            if (mediaGridView.count > 0) {
                                playlistsExpanded = false
                                var targetIdx = Math.min(index, mediaGridView.count - 1)
                                mediaGridView.currentIndex = targetIdx
                                mediaGridView.forceActiveFocus()
                                Qt.callLater(function() {
                                    if (mediaGridView.currentItem) mediaGridView.currentItem.forceActiveFocus()
                                })
                            }
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // Subtitle header for Albums when Playlists are present
        Text {
            text: "Albums & Tracks"
            font.pixelSize: 20
            font.bold: true
            color: mediaGridView.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
            visible: categoryFilter === "music" && playlistsContainer.visible
        }

        // Clean Flat Media Grid
        GridView {
            id: mediaGridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: (categoryFilter === "tvshows") ? 290 : 210
            cellHeight: (categoryFilter === "tvshows") ? 250 : 330
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
                        playlistsExpanded = true
                        if (playlistsListView && playlistsListView.count > 0) {
                            var targetIdx = Math.min(currentIndex, playlistsListView.count - 1)
                            playlistsListView.currentIndex = targetIdx
                            playlistsListView.forceActiveFocus()
                            Qt.callLater(function() {
                                if (playlistsListView.currentItem) playlistsListView.currentItem.forceActiveFocus()
                            })
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
                    var rawMusic = AppData.musicList.length > 0 ? AppData.musicList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Playlist" || i.mediaType === "MusicAlbum" || i.mediaType === "Audio" || i.mediaType === "MusicArtist" })
                    var albumsOnly = []
                    for (var m = 0; m < rawMusic.length; m++) {
                        if (rawMusic[m].mediaType !== "Playlist" && rawMusic[m].Type !== "Playlist") {
                            albumsOnly.push(rawMusic[m])
                        }
                    }
                    return albumsOnly.length > 0 ? albumsOnly : rawMusic
                } else if (categoryFilter === "favorites") {
                    return AppData.favoritesList.length > 0 ? AppData.favoritesList : AppData.mediaGrid.filter(function(i){ return i.isFavorite })
                }
                return AppData.mediaGrid
            }

            delegate: Item {
                width: mediaGridView.cellWidth
                height: mediaGridView.cellHeight
                focus: true

                property bool isShowItem: (categoryFilter === "tvshows" || modelData.mediaType === "Series" || modelData.mediaType === "series" || modelData.mediaType === "Episode" || modelData.mediaType === "TvProgram")

                onActiveFocusChanged: {
                    if (activeFocus) {
                        gridCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: gridCard
                    width: isShowItem ? 275 : 195
                    height: isShowItem ? 235 : 315
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

                        // Thumbnail Container (16:9 for Shows, 2:3 Poster for Movies)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 8
                            color: "#020617"
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: isShowItem ? (modelData.thumbUrl || modelData.backdropUrl || modelData.posterUrl) : modelData.posterUrl
                                fillMode: Image.PreserveAspectCrop
                                smooth: true
                                asynchronous: true
                                cache: true
                            }

                            // Centered Play Button Overlay for TV Shows (Matches attached screenshot)
                            Rectangle {
                                id: showPlayOverlay
                                anchors.centerIn: parent
                                width: 46
                                height: 46
                                radius: 23
                                color: "#cc0f172a"
                                border.color: "#ffffff"
                                border.width: 1
                                visible: isShowItem

                                Image {
                                    anchors.centerIn: parent
                                    width: 20
                                    height: 20
                                    source: "assets/icons/play.svg"
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            // Watched Checkmark Badge at Top Right (Matches attached screenshot)
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: 24
                                height: 24
                                radius: 12
                                color: "#0284c7"
                                visible: isShowItem && (modelData.isPlayed || false)

                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    font.pixelSize: 13
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            // Rating / Playlist Badge for Movies
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
                        }

                        Text {
                            text: isShowItem ? (modelData.seasonsEpisodesStr || modelData.subtitle || (modelData.year + " • " + modelData.duration)) : (modelData.year + " • " + modelData.duration)
                            font.pixelSize: 12
                            color: gridCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
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
                                playlistsExpanded = true
                                if (playlistsListView && playlistsListView.count > 0) {
                                    var targetIdx = Math.min(index, playlistsListView.count - 1)
                                    playlistsListView.currentIndex = targetIdx
                                    playlistsListView.forceActiveFocus()
                                    Qt.callLater(function() {
                                        if (playlistsListView.currentItem) playlistsListView.currentItem.forceActiveFocus()
                                    })
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
