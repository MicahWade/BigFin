import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: homeView
    anchors.fill: parent

    signal playRequested(var item)
    signal detailsRequested(var item)
    signal requestSidebarFocus()

    property var defaultFocusItem: (AppData.continueWatching && AppData.continueWatching.length > 0 ? continueWatchingList : ((AppData.nextUpList && AppData.nextUpList.length > 0) ? nextUpList : (moviesList.count > 0 ? moviesList : (musicList.count > 0 ? musicList : tvList))))
    property var lastFocusedItem: null

    property string savedSection: ""
    property int savedIndex: -1

    function restoreFocus() {
        if (savedSection !== "") {
            var targetList = null
            if (savedSection === "cw") targetList = continueWatchingList
            else if (savedSection === "nextup") targetList = nextUpList
            else if (savedSection === "movies") targetList = moviesList
            else if (savedSection === "music") targetList = musicList
            else if (savedSection === "tv") targetList = tvList

            if (targetList && targetList.count > 0) {
                var idx = savedIndex >= 0 ? Math.min(savedIndex, targetList.count - 1) : 0
                targetList.currentIndex = idx
                targetList.forceActiveFocus()
                if (targetList.currentItem) targetList.currentItem.forceActiveFocus()
                return true
            }
        }
        if (lastFocusedItem && lastFocusedItem.visible) {
            lastFocusedItem.forceActiveFocus()
            if (lastFocusedItem.currentItem) lastFocusedItem.currentItem.forceActiveFocus()
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

    function focusTargetList(targetList, preferredIdx) {
        if (!targetList || targetList.count <= 0) return false
        var targetIdx = Math.min(preferredIdx !== undefined ? preferredIdx : 0, targetList.count - 1)
        targetList.currentIndex = targetIdx
        targetList.forceActiveFocus()
        if (targetList.currentItem) targetList.currentItem.forceActiveFocus()
        return true
    }

    function navigateDownFrom(currentSection, currentIdx) {
        var idx = currentIdx !== undefined ? currentIdx : 0
        if (currentSection === "cw") {
            if (focusTargetList(nextUpList, idx)) return true
            if (focusTargetList(moviesList, idx)) return true
            if (focusTargetList(musicList, idx)) return true
            if (focusTargetList(tvList, idx)) return true
        } else if (currentSection === "nextup") {
            if (focusTargetList(moviesList, idx)) return true
            if (focusTargetList(musicList, idx)) return true
            if (focusTargetList(tvList, idx)) return true
        } else if (currentSection === "movies") {
            if (focusTargetList(musicList, idx)) return true
            if (focusTargetList(tvList, idx)) return true
        } else if (currentSection === "music") {
            if (focusTargetList(tvList, idx)) return true
        }
        return false
    }

    function navigateUpFrom(currentSection, currentIdx) {
        var idx = currentIdx !== undefined ? currentIdx : 0
        if (currentSection === "nextup") {
            if (focusTargetList(continueWatchingList, idx)) return true
        } else if (currentSection === "movies") {
            if (focusTargetList(nextUpList, idx)) return true
            if (focusTargetList(continueWatchingList, idx)) return true
        } else if (currentSection === "music") {
            if (focusTargetList(moviesList, idx)) return true
            if (focusTargetList(nextUpList, idx)) return true
            if (focusTargetList(continueWatchingList, idx)) return true
        } else if (currentSection === "tv") {
            if (focusTargetList(musicList, idx)) return true
            if (focusTargetList(moviesList, idx)) return true
            if (focusTargetList(nextUpList, idx)) return true
            if (focusTargetList(continueWatchingList, idx)) return true
        }
        homeView.requestSidebarFocus()
        return true
    }

    function ensureVisible(targetItem) {
        if (!targetItem) return
        var mapped = targetItem.mapToItem(mainColumn, 0, 0)
        var itemY = mapped.y
        var itemH = targetItem.height
        var viewH = mainFlickable.height
        if (viewH <= 0) return

        var targetY = (itemY + itemH / 2) - (viewH / 2)
        var maxY = Math.max(0, mainFlickable.contentHeight - viewH)
        mainFlickable.contentY = Math.max(0, Math.min(maxY, targetY))
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
                                text: AppData.isConnectedToLiveServer ? "Your Jellyfin server connected, but no movies, shows, or music were returned. Check library permissions on your server." : (AppData.connectionError ? AppData.connectionError : "Unable to reach your Jellyfin server. Please check connection settings.")
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

                    Keys.onLeftPressed: function(event) {
                        if (currentIndex <= 0) {
                            homeView.requestSidebarFocus()
                        } else {
                            currentIndex = currentIndex - 1
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                        event.accepted = true
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
                                    homeView.ensureVisible(cwCard)
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
                                navigateDownFrom("cw", index)
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
            // 1.5 NEXT UP / NEXT EPISODE ROW (UNDER CONTINUE WATCHING)
            // ==========================================
            ColumnLayout {
                id: nextUpContainer
                Layout.fillWidth: true
                Layout.leftMargin: 48
                Layout.rightMargin: 48
                spacing: 14
                visible: AppData.nextUpList && AppData.nextUpList.length > 0

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Next Up"
                        font.pixelSize: 24
                        font.bold: true
                        color: nextUpList.activeFocus || nextUpContainer.activeFocus ? AppData.currentTheme.accent : "#f8fafc"
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: (AppData.nextUpList ? AppData.nextUpList.length : 0) + " Episodes"
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }

                ListView {
                    id: nextUpList
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

                    model: AppData.nextUpList

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mainFlickable.contentY = 320
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    Keys.onLeftPressed: function(event) {
                        if (currentIndex <= 0) {
                            homeView.requestSidebarFocus()
                        } else {
                            currentIndex = currentIndex - 1
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    delegate: Item {
                        id: nuDelegateItem
                        width: 320
                        height: 230
                        z: nuCard.activeFocus ? 100 : 1
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                nuCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: nuCard
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
                                    homeView.lastFocusedItem = nuCard
                                    homeView.ensureVisible(nuCard)
                                    nextUpList.currentIndex = index
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
                                        source: modelData.backdropUrl || modelData.posterUrl || modelData.thumbUrl
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
                                        color: nuCard.activeFocus ? AppData.currentTheme.accent : "#cc0f172a"

                                        Image {
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: "assets/icons/play.svg"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    // Next Up Pill
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 8
                                        height: 22
                                        width: 76
                                        radius: 4
                                        color: "#d06366f1"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "NEXT UP"
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: "#ffffff"
                                        }
                                    }
                                }

                                Text {
                                    text: modelData.seriesName || modelData.title
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: nuCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.epCode ? (modelData.epCode + (modelData.episodeName ? (" - " + modelData.episodeName) : "")) : (modelData.subtitle || modelData.title)
                                    font.pixelSize: 12
                                    color: nuCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    nextUpList.currentIndex = index
                                    nuCard.forceActiveFocus()
                                    homeView.playRequested(modelData)
                                }
                            }

                            Keys.onReturnPressed: homeView.playRequested(modelData)
                            Keys.onSpacePressed: homeView.detailsRequested(modelData)

                            Keys.onUpPressed: function(event) {
                                navigateUpFrom("nextup", index)
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("nextup", index)
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index === 0) {
                                    homeView.requestSidebarFocus()
                                    event.accepted = true
                                } else if (index > 0) {
                                    nextUpList.currentIndex = index - 1
                                    if (nextUpList.currentItem) nextUpList.currentItem.forceActiveFocus()
                                    event.accepted = true
                                }
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < nextUpList.count - 1) {
                                    nextUpList.currentIndex = index + 1
                                    if (nextUpList.currentItem) nextUpList.currentItem.forceActiveFocus()
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
                    Layout.preferredHeight: 315
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

                    Keys.onLeftPressed: function(event) {
                        if (currentIndex <= 0) {
                            homeView.requestSidebarFocus()
                        } else {
                            currentIndex = currentIndex - 1
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    delegate: Item {
                        width: 180
                        height: 305
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
                            height: 295
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
                                    homeView.ensureVisible(movieCard)
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
                                        fillMode: Image.PreserveAspectFit
                                        verticalAlignment: Image.AlignVCenter
                                        horizontalAlignment: Image.AlignHCenter
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
                                        visible: AppData.isRatingVisible(modelData)

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
                                navigateUpFrom("movies", index)
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("movies", index)
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
                            mainFlickable.contentY = 480
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                    }

                    Keys.onLeftPressed: function(event) {
                        if (currentIndex <= 0) {
                            homeView.requestSidebarFocus()
                        } else {
                            currentIndex = currentIndex - 1
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                        event.accepted = true
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
                                    homeView.ensureVisible(musicCard)
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
                                        fillMode: Image.PreserveAspectFit
                                        verticalAlignment: Image.AlignVCenter
                                        horizontalAlignment: Image.AlignHCenter
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
                                navigateUpFrom("music", index)
                                event.accepted = true
                            }

                            Keys.onDownPressed: function(event) {
                                navigateDownFrom("music", index)
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
                    Layout.preferredHeight: 315
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

                    Keys.onLeftPressed: function(event) {
                        if (currentIndex <= 0) {
                            homeView.requestSidebarFocus()
                        } else {
                            currentIndex = currentIndex - 1
                            if (currentItem) currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    delegate: Item {
                        width: 180
                        height: 305
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
                            height: 295
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
                                    homeView.ensureVisible(tvCard)
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
                                        fillMode: Image.PreserveAspectFit
                                        verticalAlignment: Image.AlignVCenter
                                        horizontalAlignment: Image.AlignHCenter
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
                                        visible: AppData.isRatingVisible(modelData)

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
                                    text: modelData.title || modelData.episodeName || "Show"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: tvCard.activeFocus ? "#ffffff" : "#e2e8f0"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: modelData.seasonsEpisodesStr || modelData.subtitle || (modelData.year || "2024")
                                    font.pixelSize: 12
                                    color: tvCard.activeFocus ? "#e2e8f0" : "#94a3b8"
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
                                navigateUpFrom("tv", index)
                                event.accepted = true
                            }

                            Keys.onLeftPressed: function(event) {
                                if (index <= 0) {
                                    homeView.requestSidebarFocus()
                                } else {
                                    tvList.currentIndex = index - 1
                                    if (tvList.currentItem) tvList.currentItem.forceActiveFocus()
                                }
                                event.accepted = true
                            }

                            Keys.onRightPressed: function(event) {
                                if (index < tvList.count - 1) {
                                    tvList.currentIndex = index + 1
                                    if (tvList.currentItem) tvList.currentItem.forceActiveFocus()
                                }
                                event.accepted = true
                            }
                        }
                    }
                }
            }
        }
    }
}
