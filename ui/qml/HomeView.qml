import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: homeView
    anchors.fill: parent

    signal playRequested(var item)
    signal detailsRequested(var item)
    signal requestSidebarFocus()

    property var defaultFocusItem: (AppData.continueWatching.length > 0 ? continueWatchingList : (moviesList.count > 0 ? moviesList : (musicList.count > 0 ? musicList : tvList)))
    property var lastFocusedItem: null

    function restoreFocus() {
        if (lastFocusedItem && lastFocusedItem.visible) {
            lastFocusedItem.forceActiveFocus()
            return true
        }
        var def = defaultFocusItem
        if (def) {
            def.forceActiveFocus()
            if (def.currentItem) def.currentItem.forceActiveFocus()
            return true
        }
        return false
    }

    function navigateDownFrom(currentSection) {
        if (currentSection === "cw") {
            if (moviesList.count > 0) { moviesList.forceActiveFocus(); if (moviesList.currentItem) moviesList.currentItem.forceActiveFocus(); return true; }
            if (musicList.count > 0) { musicList.forceActiveFocus(); if (musicList.currentItem) musicList.currentItem.forceActiveFocus(); return true; }
            if (tvList.count > 0) { tvList.forceActiveFocus(); if (tvList.currentItem) tvList.currentItem.forceActiveFocus(); return true; }
        } else if (currentSection === "movies") {
            if (musicList.count > 0) { musicList.forceActiveFocus(); if (musicList.currentItem) musicList.currentItem.forceActiveFocus(); return true; }
            if (tvList.count > 0) { tvList.forceActiveFocus(); if (tvList.currentItem) tvList.currentItem.forceActiveFocus(); return true; }
        } else if (currentSection === "music") {
            if (tvList.count > 0) { tvList.forceActiveFocus(); if (tvList.currentItem) tvList.currentItem.forceActiveFocus(); return true; }
        }
        return false
    }

    function navigateUpFrom(currentSection) {
        if (currentSection === "movies") {
            if (AppData.continueWatching.length > 0) { continueWatchingList.forceActiveFocus(); if (continueWatchingList.currentItem) continueWatchingList.currentItem.forceActiveFocus(); return true; }
        } else if (currentSection === "music") {
            if (moviesList.count > 0) { moviesList.forceActiveFocus(); if (moviesList.currentItem) moviesList.currentItem.forceActiveFocus(); return true; }
            if (AppData.continueWatching.length > 0) { continueWatchingList.forceActiveFocus(); if (continueWatchingList.currentItem) continueWatchingList.currentItem.forceActiveFocus(); return true; }
        } else if (currentSection === "tv") {
            if (musicList.count > 0) { musicList.forceActiveFocus(); if (musicList.currentItem) musicList.currentItem.forceActiveFocus(); return true; }
            if (moviesList.count > 0) { moviesList.forceActiveFocus(); if (moviesList.currentItem) moviesList.currentItem.forceActiveFocus(); return true; }
            if (AppData.continueWatching.length > 0) { continueWatchingList.forceActiveFocus(); if (continueWatchingList.currentItem) continueWatchingList.currentItem.forceActiveFocus(); return true; }
        }
        homeView.requestSidebarFocus()
        return true
    }

    Flickable {
        id: mainFlickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 80
        clip: true

        Behavior on contentY {
            NumberAnimation { duration: 250; easing.type: "OutCubic" }
        }

        ColumnLayout {
            id: mainColumn
            width: mainFlickable.width
            spacing: 36
            // Connection Error / Empty Library Banner
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                Layout.topMargin: 24
                spacing: 16
                visible: !AppData.isConnectedToLiveServer || (AppData.moviesList.length === 0 && AppData.tvShowsList.length === 0 && AppData.musicList.length === 0 && AppData.continueWatching.length === 0)

                Rectangle {
                    Layout.fillWidth: true
                    height: 140
                    radius: 16
                    color: AppData.isConnectedToLiveServer ? "#0f172a" : "#3f1212"
                    border.color: AppData.isConnectedToLiveServer ? "#334155" : "#ef4444"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 24
                        spacing: 24

                        Rectangle {
                            width: 56
                            height: 56
                            radius: 28
                            color: AppData.isConnectedToLiveServer ? "#1e293b" : "#ef4444"

                            Text {
                                anchors.centerIn: parent
                                text: AppData.isConnectedToLiveServer ? "i" : "!"
                                font.pixelSize: 32
                                font.bold: true
                                color: "#ffffff"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: AppData.isConnectedToLiveServer ? "No Media Found in Jellyfin Library" : "Not Connected to Jellyfin Server"
                                font.pixelSize: 22
                                font.bold: true
                                color: "#ffffff"
                            }

                            Text {
                                text: AppData.isConnectedToLiveServer ? "Your Jellyfin server connected, but no movies, TV series, or music were returned. Check library permissions on your server." : (AppData.connectionError ? AppData.connectionError : "Unable to reach your Jellyfin server. Please check connection settings.")
                                font.pixelSize: 14
                                color: AppData.isConnectedToLiveServer ? "#94a3b8" : "#fca5a5"
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 1. TOP SECTION: CONTINUE WATCHING (SELECTED ITEM IS TOP MOST)
            // ==========================================
            ColumnLayout {
                id: cwContainer
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                Layout.topMargin: 24
                spacing: 14
                visible: AppData.continueWatching.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Continue Watching"
                        font.pixelSize: 24
                        font.bold: true
                        color: continueWatchingList.activeFocus || cwContainer.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: AppData.continueWatching.length + " Items"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: continueWatchingList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    orientation: ListView.Horizontal
                    spacing: 20
                    clip: false
                    focus: true
                    keyNavigationWraps: false
                    highlightMoveDuration: 75
                    highlightResizeDuration: 75
                    maximumFlickVelocity: 6000
                    flickDeceleration: 8000

                    model: AppData.continueWatching

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mainFlickable.contentY = 0
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    delegate: Item {
                        id: cwDelegateItem
                        width: 320
                        height: 230
                        z: cwCard.activeFocus ? 100 : 1
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                cwCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: cwCard
                            width: 310
                            height: 220
                            anchors.centerIn: parent
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            focus: true

                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            Behavior on color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    homeView.lastFocusedItem = cwCard
                                    mainFlickable.contentY = 0
                                    continueWatchingList.currentIndex = index
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                // Thumbnail Container
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.backdropUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }

                                    // Play Overlay Icon
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 44
                                        height: 44
                                        radius: 22
                                        color: cwCard.activeFocus ? AppData.currentTheme.accent : "#cc0f172a"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: "assets/icons/play.svg"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    // Time Remaining Pill
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        height: 22
                                        width: 90
                                        radius: 4
                                        color: "#d0020617"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.timeLeft || "In Progress"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#e2e8f0"
                                        }
                                    }

                                    // Progress Bar
                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 5
                                        color: "#334155"

                                        Rectangle {
                                            width: parent.width * (modelData.progress || 0.5)
                                            height: parent.height
                                            color: cwCard.activeFocus ? AppData.currentTheme.accent : "#38bdf8"
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: cwCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.subtitle || "Direct Stream"
                                    font.pixelSize: 12
                                    color: cwCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    continueWatchingList.currentIndex = index
                                    cwCard.forceActiveFocus()
                                    homeView.playRequested(modelData)
                                }
                            }

                            Keys.onReturnPressed: homeView.playRequested(modelData)
                            Keys.onSpacePressed: homeView.playRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                homeView.requestSidebarFocus()
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("cw")
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    homeView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    continueWatchingList.currentIndex = index - 1
                                    if (continueWatchingList.currentItem) continueWatchingList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < continueWatchingList.count - 1) {
                                    continueWatchingList.currentIndex = index + 1
                                    if (continueWatchingList.currentItem) continueWatchingList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 2. RECENTLY ADDED IN MOVIES ROW
            // ==========================================
            ColumnLayout {
                id: moviesContainer
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14
                visible: (AppData.recentlyAddedMovies.length > 0 || AppData.moviesList.length > 0)

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Recently Added in Movies >"
                        font.pixelSize: 22
                        font.bold: true
                        color: moviesList.activeFocus || moviesContainer.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (AppData.recentlyAddedMovies.length || AppData.moviesList.length) + " Titles"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: moviesList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    orientation: ListView.Horizontal
                    spacing: 22
                    clip: false
                    focus: true
                    keyNavigationWraps: false
                    highlightMoveDuration: 75
                    highlightResizeDuration: 75
                    maximumFlickVelocity: 6000
                    flickDeceleration: 8000

                    model: AppData.recentlyAddedMovies.length > 0 ? AppData.recentlyAddedMovies : AppData.moviesList

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mainFlickable.contentY = 140
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    delegate: Item {
                        width: 180
                        height: 280
                        z: movieCard.activeFocus ? 100 : 1
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                movieCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: movieCard
                            width: 172
                            height: 270
                            anchors.centerIn: parent
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            scale: activeFocus ? 1.08 : 1.0
                            focus: true

                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    homeView.lastFocusedItem = movieCard
                                    mainFlickable.contentY = 140
                                    moviesList.currentIndex = index
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        height: 20
                                        width: 50
                                        radius: 4
                                        color: "#d00f172a"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "★ " + (modelData.rating || "8.5")
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#fbbf24"
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: movieCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.year || "2024"
                                    font.pixelSize: 12
                                    color: "#94a3b8"
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    moviesList.currentIndex = index
                                    movieCard.forceActiveFocus()
                                    homeView.detailsRequested(modelData)
                                }
                            }

                            Keys.onReturnPressed: homeView.playRequested(modelData)
                            Keys.onSpacePressed: homeView.detailsRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                navigateUpFrom("movies")
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("movies")
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    homeView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    moviesList.currentIndex = index - 1
                                    if (moviesList.currentItem) moviesList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < moviesList.count - 1) {
                                    moviesList.currentIndex = index + 1
                                    if (moviesList.currentItem) moviesList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 3. RECENTLY ADDED IN MUSIC ROW
            // ==========================================
            ColumnLayout {
                id: musicContainer
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14
                visible: (AppData.recentlyAddedMusic.length > 0 || AppData.musicList.length > 0)

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Recently Added in Music >"
                        font.pixelSize: 22
                        font.bold: true
                        color: musicList.activeFocus || musicContainer.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (AppData.recentlyAddedMusic.length || AppData.musicList.length) + " Albums"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: musicList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 250
                    orientation: ListView.Horizontal
                    spacing: 22
                    clip: false
                    focus: true
                    keyNavigationWraps: false
                    highlightMoveDuration: 75
                    highlightResizeDuration: 75
                    maximumFlickVelocity: 6000
                    flickDeceleration: 8000

                    model: AppData.recentlyAddedMusic.length > 0 ? AppData.recentlyAddedMusic : AppData.musicList

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mainFlickable.contentY = 380
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    delegate: Item {
                        width: 180
                        height: 240
                        z: musicCard.activeFocus ? 100 : 1
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                musicCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: musicCard
                            width: 172
                            height: 230
                            anchors.centerIn: parent
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            scale: activeFocus ? 1.08 : 1.0
                            focus: true

                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    homeView.lastFocusedItem = musicCard
                                    mainFlickable.contentY = 380
                                    musicList.currentIndex = index
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // Square Cover Art for Music
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 156
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: musicCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.subtitle || "Artist"
                                    font.pixelSize: 11
                                    color: "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    musicList.currentIndex = index
                                    musicCard.forceActiveFocus()
                                    homeView.detailsRequested(modelData)
                                }
                            }

                            Keys.onReturnPressed: homeView.playRequested(modelData)
                            Keys.onSpacePressed: homeView.detailsRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                navigateUpFrom("music")
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("music")
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    homeView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    musicList.currentIndex = index - 1
                                    if (musicList.currentItem) musicList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < musicList.count - 1) {
                                    musicList.currentIndex = index + 1
                                    if (musicList.currentItem) musicList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }
                        }
                    }
                }
            }

            // ==========================================
            // 4. RECENTLY ADDED IN SHOWS ROW
            // ==========================================
            ColumnLayout {
                id: tvContainer
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14
                visible: ((AppData.recentlyAddedShows && AppData.recentlyAddedShows.length > 0) || (AppData.tvShowsList && AppData.tvShowsList.length > 0))

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Recently Added in Shows >"
                        font.pixelSize: 22
                        font.bold: true
                        color: tvList.activeFocus || tvContainer.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: ((AppData.recentlyAddedShows && AppData.recentlyAddedShows.length) || (AppData.tvShowsList && AppData.tvShowsList.length) || 0) + " Shows"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: tvList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 290
                    orientation: ListView.Horizontal
                    spacing: 22
                    clip: false
                    focus: true
                    keyNavigationWraps: false
                    highlightMoveDuration: 75
                    highlightResizeDuration: 75
                    maximumFlickVelocity: 6000
                    flickDeceleration: 8000

                    model: (AppData.recentlyAddedShows && AppData.recentlyAddedShows.length > 0) ? AppData.recentlyAddedShows : AppData.tvShowsList

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mainFlickable.contentY = 620
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    delegate: Item {
                        width: 180
                        height: 280
                        z: tvCard.activeFocus ? 100 : 1
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                tvCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: tvCard
                            width: 172
                            height: 270
                            anchors.centerIn: parent
                            radius: 12
                            color: activeFocus ? AppData.currentTheme.focusCard : "#090d16"
                            border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                            border.width: activeFocus ? 4 : 1
                            scale: activeFocus ? 1.08 : 1.0
                            focus: true

                            Behavior on scale { NumberAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                if (activeFocus) {
                                    homeView.lastFocusedItem = tvCard
                                    mainFlickable.contentY = 620
                                    tvList.currentIndex = index
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#020617"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: modelData.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                        smooth: true
                                        asynchronous: true
                                    }
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: tvCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.seasonsEpisodesStr || modelData.subtitle || "Series"
                                    font.pixelSize: 12
                                    color: "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    tvList.currentIndex = index
                                    tvCard.forceActiveFocus()
                                    homeView.detailsRequested(modelData)
                                }
                            }

                            Keys.onReturnPressed: homeView.detailsRequested(modelData)
                            Keys.onSpacePressed: homeView.detailsRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                navigateUpFrom("tv")
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    homeView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    tvList.currentIndex = index - 1
                                    if (tvList.currentItem) tvList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < tvList.count - 1) {
                                    tvList.currentIndex = index + 1
                                    if (tvList.currentItem) tvList.currentItem.forceActiveFocus()
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
