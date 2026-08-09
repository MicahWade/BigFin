import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: mainShell
    anchors.fill: parent

    property string currentView: "home"
    property var selectedMediaItem: null
    property var viewHistoryStack: ["home"]

    // Startup Server IP Dialog State
    property bool showStartupServerModal: !AppData.isAuthenticated
    property bool showSessionSwitchModal: false
    property string configuredServerIp: "http://localhost:8096"
    property string serverName: "Bigfin"

    // Dynamic Theme Gradient Background (Updates Real-time when Theme Changes)
    Rectangle {
        anchors.fill: parent
        z: -10
        gradient: Gradient {
            GradientStop { position: 0.0; color: AppData.currentTheme.bgStop1 }
            GradientStop { position: 0.5; color: AppData.currentTheme.bgStop2 }
            GradientStop { position: 1.0; color: AppData.currentTheme.bgStop3 }
        }

        Behavior on color { ColorAnimation { duration: 300 } }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ==========================================
        // COLLAPSIBLE TV SIDEBAR NAVIGATION
        // ==========================================
        Rectangle {
            id: sidebarContainer
            Layout.fillHeight: true
            Layout.preferredWidth: isSidebarFocused ? 260 : 84
            color: "#090d16"
            border.color: "#1e293b"
            border.width: 1
            z: 20

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 180; easing.type: "OutCubic" }
            }

            property bool isSidebarFocused: sidebarListView.activeFocus || (sidebarListView.currentItem && sidebarListView.currentItem.activeFocus) || sidebarListView.currentItemFocused

            ColumnLayout {
                anchors.fill: parent
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                spacing: 24

                // App Brand Logo (Displays User Provided Logo.png)
                RowLayout {
                    Layout.leftMargin: 20
                    spacing: 14

                    Rectangle {
                        width: 44
                        height: 44
                        radius: 12
                        color: "#0f172a"
                        border.color: AppData.currentTheme.accent
                        border.width: 1
                        clip: true

                        Image {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            source: "assets/Logo.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Text {
                        text: "Bigfin"
                        font.pixelSize: 26
                        font.bold: true
                        color: "#ffffff"
                        visible: sidebarContainer.Layout.preferredWidth > 120
                        opacity: visible ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }
                }

                // Sidebar Nav Item List
                ListView {
                    id: sidebarListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    focus: true
                    model: AppData.sidebarCategories
                    keyNavigationWraps: true

                    property bool currentItemFocused: false

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            if (currentItem) currentItem.forceActiveFocus()
                        } else {
                            currentItemFocused = false
                        }
                    }

                    delegate: Item {
                        id: delegateItem
                        width: sidebarListView.width
                        height: 54
                        focus: true

                        onActiveFocusChanged: {
                            if (activeFocus) {
                                navItemCard.forceActiveFocus()
                            }
                        }

                        Rectangle {
                            id: navItemCard
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            radius: 12
                            color: (navMouseArea.containsMouse || activeFocus) ? AppData.currentTheme.focusCard : (mainShell.currentView === modelData.id ? "#0f172a" : "transparent")
                            border.color: (navMouseArea.containsMouse || activeFocus) ? AppData.currentTheme.accent : "transparent"
                            border.width: (navMouseArea.containsMouse || activeFocus) ? 2 : 0
                            focus: true

                            Behavior on color { ColorAnimation { duration: 120 } }

                            onActiveFocusChanged: {
                                sidebarListView.currentItemFocused = activeFocus
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 18
                                spacing: 16

                                Image {
                                    width: 22
                                    height: 22
                                    source: modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: (navMouseArea.containsMouse || navItemCard.activeFocus) ? "#ffffff" : (mainShell.currentView === modelData.id ? AppData.currentTheme.accent : "#94a3b8")
                                    visible: sidebarContainer.Layout.preferredWidth > 120
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: navMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    sidebarListView.currentIndex = index
                                    navItemCard.forceActiveFocus()
                                    switchView(modelData.id)
                                }
                            }

                            Keys.onReturnPressed: switchView(modelData.id)
                            Keys.onEnterPressed: switchView(modelData.id)
                            Keys.onSelectPressed: switchView(modelData.id)
                            Keys.onSpacePressed: switchView(modelData.id)
                            Keys.onRightPressed: moveFocusToView()
                        }
                    }
                }

                // Live Server Connection Status & Session Switcher Indicator Button
                Rectangle {
                    id: sessionStatusBox
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 12
                    height: 44
                    radius: 8
                    color: (sessionMouse.containsMouse || activeFocus) ? AppData.currentTheme.focusCard : "transparent"
                    border.color: (sessionMouse.containsMouse || activeFocus) ? AppData.currentTheme.accent : "transparent"
                    border.width: (sessionMouse.containsMouse || activeFocus) ? 2 : 0
                    focus: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: AppData.isAuthenticated ? "#22c55e" : "#ef4444"
                        }

                        Text {
                            text: AppData.isAuthenticated ? ((AppData.authenticatedUser !== "" ? AppData.authenticatedUser : "Account") + " (" + (AppData.serverName !== "" ? AppData.serverName : "Jellyfin") + ")") : "NOT CONNECTED"
                            font.pixelSize: 11
                            font.bold: true
                            color: AppData.isAuthenticated ? "#22c55e" : "#ef4444"
                            visible: sidebarContainer.Layout.preferredWidth > 120
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        id: sessionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionStatusBox.forceActiveFocus()
                            mainShell.showSessionSwitchModal = true
                        }
                    }

                    Keys.onReturnPressed: mainShell.showSessionSwitchModal = true
                    Keys.onSpacePressed: mainShell.showSessionSwitchModal = true
                }
            }
        }

        // ==========================================
        // MAIN VIEW CONTAINER LOADER
        // ==========================================
        Item {
            id: viewArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: viewLoader
                anchors.fill: parent
                source: "HomeView.qml"

                onLoaded: {
                    if (item) {
                        if (mainShell.currentView === "details") {
                            item.item = mainShell.selectedMediaItem
                        } else if (mainShell.currentView === "movies" || mainShell.currentView === "tvshows" || mainShell.currentView === "music" || mainShell.currentView === "favorites") {
                            item.categoryFilter = mainShell.currentView
                            if (mainShell.currentView === "music") {
                                item.musicSubFilter = AppData.activeMusicSubFilter
                            }
                        }
                        if (item.restoreFocus && typeof item.restoreFocus === "function") {
                            item.restoreFocus()
                        } else if (item.defaultFocusItem && !sidebarContainer.isSidebarFocused && !mainShell.showStartupServerModal) {
                            item.defaultFocusItem.forceActiveFocus()
                        }
                    }
                }
            }

            // Dedicated Music Mini-Player (Persistent Bottom Bar while browsing views)
            Loader {
                id: miniPlayerLoader
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                height: 68
                active: AppData.isMusicMiniPlayerVisible
                source: "components/MusicMiniPlayer.qml"
                z: 80

                onLoaded: {
                    if (item) {
                        item.expandRequested.connect(function() {
                            navigateTo("player", AppData.currentMusicTrack)
                        })
                    }
                }
            }
        }
    }

    function isMusicItem(item) {
        if (!item) return false
        return AppData.isMusicMedia(item)
    }

    // Fullscreen Overlay Container (Dynamic Music vs Video Player)
    Loader {
        id: playerLoader
        anchors.fill: parent
        active: mainShell.currentView === "player"
        source: mainShell.isMusicItem(mainShell.selectedMediaItem) ? "MusicPlayerOverlay.qml" : "PlayerOverlay.qml"
        z: 100

        onLoaded: {
            if (item) {
                item.item = mainShell.selectedMediaItem
                item.forceActiveFocus()
            }
        }
    }

    // JELLYFIN SESSION SWITCHER & MULTI-ACCOUNT MODAL
    Loader {
        id: sessionModalLoader
        anchors.fill: parent
        active: mainShell.showSessionSwitchModal
        source: "SessionSwitchModal.qml"
        z: 250

        onLoaded: {
            if (item) {
                item.forceActiveFocus()
            }
        }
    }

    Connections {
        target: sessionModalLoader.item
        ignoreUnknownSignals: true

        function onSessionSwitched(session) {
            mainShell.showSessionSwitchModal = false
            moveFocusToView()
        }

        function onAddAccountRequested() {
            mainShell.showSessionSwitchModal = false
            mainShell.showStartupServerModal = true
        }

        function onCloseRequested() {
            mainShell.showSessionSwitchModal = false
            moveFocusToView()
        }
    }

    // STARTUP JELLYFIN SERVER CONNECTION LOADING SCREEN
    property bool showConnectingLoadingOverlay: false

    Loader {
        id: loadingOverlayLoader
        anchors.fill: parent
        active: mainShell.showConnectingLoadingOverlay
        source: "ConnectionLoadingOverlay.qml"
        z: 400
    }

    Connections {
        target: loadingOverlayLoader.item
        ignoreUnknownSignals: true

        function onConnectionComplete() {
            mainShell.showConnectingLoadingOverlay = false
            moveFocusToView()
        }

        function onOpenConnectModalRequested() {
            mainShell.showConnectingLoadingOverlay = false
            mainShell.showStartupServerModal = true
        }
    }

    // STARTUP JELLYFIN SERVER IP SETUP MODAL
    Loader {
        id: serverModalLoader
        anchors.fill: parent
        active: mainShell.showStartupServerModal && !mainShell.showConnectingLoadingOverlay
        source: "ServerConnectModal.qml"
        z: 300

        onLoaded: {
            if (item) {
                item.forceActiveFocus()
            }
        }
    }

    Connections {
        target: serverModalLoader.item
        ignoreUnknownSignals: true

        function onServerConnected(serverIp, serverName, username, token) {
            mainShell.configuredServerIp = serverIp
            mainShell.serverName = serverName
            AppData.liveServerUrl = serverIp
            AppData.serverName = serverName
            AppData.isConnectedToLiveServer = true
            mainShell.showStartupServerModal = false
            moveFocusToView()
        }
    }

    Connections {
        target: AppData
        ignoreUnknownSignals: true

        function onConnectionFailed(msg) {
            console.log("[MAIN] Connection failed: " + msg + ". Bringing up server connect modal popup...")
            mainShell.showConnectingLoadingOverlay = false
            mainShell.showStartupServerModal = true
        }

        function onFavoritesListChanged() {
            if (mainShell.currentView === "favorites" && (!AppData.favoritesList || AppData.favoritesList.length === 0)) {
                console.log("[MAIN] Favorites list is empty. Redirecting to Home...")
                switchView("home")
            }
        }
    }

    // Connections to child views
    Connections {
        target: viewLoader.item
        ignoreUnknownSignals: true

        function onRequestSidebarFocus() {
            sidebarListView.forceActiveFocus()
            if (sidebarListView.currentItem) {
                sidebarListView.currentItem.forceActiveFocus()
            }
        }

        function onPlayRequested(item) {
            console.log("[MAIN] Play requested for: " + (item ? item.title : "unknown"))
            mainShell.selectedMediaItem = item
            if (mainShell.isMusicItem(item)) {
                AppData.playMusicItem(item)
            } else {
                AppData.updateMusicSubFilterForMediaItem(item)
            }
            navigateTo("player", item)
        }

        function onDetailsRequested(item) {
            mainShell.selectedMediaItem = item
            AppData.updateMusicSubFilterForMediaItem(item)
            navigateTo("details", item)
        }

        function onItemSelected(item) {
            mainShell.selectedMediaItem = item
            AppData.updateMusicSubFilterForMediaItem(item)
            navigateTo("details", item)
        }

        function onBackRequested() {
            goBack()
        }

        function onOpenSessionSwitcher() {
            mainShell.showSessionSwitchModal = true
        }
    }

    Connections {
        target: playerLoader.item
        ignoreUnknownSignals: true

        function onCloseRequested() {
            goBack()
        }
    }

    // Navigation Stack Engine
    function getCurrentSpot() {
        if (!viewLoader.item) return { savedIndex: -1, savedSection: "" }
        var item = viewLoader.item
        if (item.mediaGridView !== undefined && item.mediaGridView !== null) {
            return { savedIndex: item.mediaGridView.currentIndex, savedSection: "" }
        }
        if (item.searchResultsGrid !== undefined && item.searchResultsGrid !== null) {
            return { savedIndex: item.searchResultsGrid.currentIndex, savedSection: "" }
        }
        if (item.lastFocusedItem !== undefined && item.lastFocusedItem !== null) {
            var section = ""
            var idx = -1
            if (item.lastFocusedItem === item.continueWatchingList) section = "cw"
            else if (item.lastFocusedItem === item.nextUpList) section = "nextup"
            else if (item.lastFocusedItem === item.moviesList) section = "movies"
            else if (item.lastFocusedItem === item.musicList) section = "music"
            else if (item.lastFocusedItem === item.tvList) section = "tv"
            if (item.lastFocusedItem.currentIndex !== undefined) idx = item.lastFocusedItem.currentIndex
            return { savedSection: section, savedIndex: idx }
        }
        return { savedIndex: -1, savedSection: "" }
    }

    function navigateTo(viewId, extraData) {
        if (mainShell.currentView !== viewId) {
            var spot = getCurrentSpot()
            var stack = mainShell.viewHistoryStack.slice()
            var entry = { view: mainShell.currentView, savedIndex: spot.savedIndex, savedSection: spot.savedSection, subFilter: (mainShell.currentView === "music" ? AppData.activeMusicSubFilter : "") }
            stack.push(entry)
            mainShell.viewHistoryStack = stack
        }

        if (extraData) {
            mainShell.selectedMediaItem = extraData
            AppData.updateMusicSubFilterForMediaItem(extraData)
        }

        mainShell.currentView = viewId
        if (viewId === "home") {
            viewLoader.source = "HomeView.qml"
        } else if (viewId === "movies" || viewId === "tvshows" || viewId === "music" || viewId === "favorites") {
            viewLoader.source = "GridView.qml"
            if (viewLoader.item) {
                viewLoader.item.categoryFilter = viewId
                if (viewId === "music") {
                    viewLoader.item.musicSubFilter = AppData.activeMusicSubFilter
                }
            }
        } else if (viewId === "search") {
            viewLoader.source = "SearchView.qml"
        } else if (viewId === "settings") {
            viewLoader.source = "SettingsView.qml"
            if (viewLoader.item) {
                viewLoader.item.serverUrl = mainShell.configuredServerIp
            }
        } else if (viewId === "details") {
            viewLoader.source = "DetailsView.qml"
            if (viewLoader.item) {
                viewLoader.item.item = mainShell.selectedMediaItem
            }
        } else if (viewId === "player") {
            if (playerLoader.item) {
                playerLoader.item.item = mainShell.selectedMediaItem
                playerLoader.item.forceActiveFocus()
            }
        }
    }

    function switchView(viewId) {
        navigateTo(viewId)
        sidebarListView.forceActiveFocus()
        if (sidebarListView.currentItem) {
            sidebarListView.currentItem.forceActiveFocus()
        }
    }

    function goBack() {
        var stack = mainShell.viewHistoryStack.slice()
        if (stack.length > 0) {
            var prevEntry = stack.pop()
            mainShell.viewHistoryStack = stack

            var prevView = (typeof prevEntry === "object" && prevEntry !== null) ? prevEntry.view : prevEntry
            var savedIdx = (typeof prevEntry === "object" && prevEntry !== null && prevEntry.savedIndex !== undefined) ? prevEntry.savedIndex : -1
            var savedSec = (typeof prevEntry === "object" && prevEntry !== null && prevEntry.savedSection !== undefined) ? prevEntry.savedSection : ""

            if (typeof prevEntry === "object" && prevEntry !== null && prevEntry.subFilter) {
                AppData.activeMusicSubFilter = prevEntry.subFilter
            }
            mainShell.currentView = prevView

            if (prevView === "home") {
                viewLoader.source = "HomeView.qml"
            } else if (prevView === "movies" || prevView === "tvshows" || prevView === "music" || prevView === "favorites") {
                viewLoader.source = "GridView.qml"
                if (viewLoader.item) {
                    viewLoader.item.categoryFilter = prevView
                    if (prevView === "music") {
                        viewLoader.item.musicSubFilter = AppData.activeMusicSubFilter
                    }
                }
            } else if (prevView === "search") {
                viewLoader.source = "SearchView.qml"
            } else if (prevView === "settings") {
                viewLoader.source = "SettingsView.qml"
            } else if (prevView === "details") {
                viewLoader.source = "DetailsView.qml"
            }

            if (viewLoader.item) {
                if (savedIdx >= 0 && viewLoader.item.savedIndex !== undefined) viewLoader.item.savedIndex = savedIdx
                if (savedSec !== "" && viewLoader.item.savedSection !== undefined) viewLoader.item.savedSection = savedSec
                if (viewLoader.item.restoreFocus && typeof viewLoader.item.restoreFocus === "function") {
                    viewLoader.item.restoreFocus()
                } else {
                    viewLoader.forceActiveFocus()
                }
            } else {
                viewLoader.forceActiveFocus()
            }
        } else {
            mainShell.currentView = "home"
            viewLoader.source = "HomeView.qml"
            viewLoader.forceActiveFocus()
        }
    }

    function moveFocusToView() {
        if (viewLoader.item) {
            if (viewLoader.item.restoreFocus && typeof viewLoader.item.restoreFocus === "function") {
                if (viewLoader.item.restoreFocus()) {
                    return
                }
            }
            viewLoader.item.forceActiveFocus()
            var focusItem = viewLoader.item.defaultFocusItem
            if (focusItem) {
                focusItem.forceActiveFocus()
                if (focusItem.currentItem) {
                    focusItem.currentItem.forceActiveFocus()
                }
            }
        }
    }

    // Global Key Bindings for Keyboard & Gamepad Controller
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace || event.key === Qt.Key_Back) {
            if (mainShell.showStartupServerModal) {
                // Cannot bypass modal until authenticated
                event.accepted = true
            } else {
                goBack()
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Down || event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
            // Safety Focus Recovery Net: If an arrow key reaches mainShell, recover active focus
            if (mainShell.showSessionSwitchModal && sessionModalLoader.item) {
                sessionModalLoader.item.forceActiveFocus()
            } else if (mainShell.showStartupServerModal && serverModalLoader.item) {
                serverModalLoader.item.forceActiveFocus()
            } else if (sidebarContainer.isSidebarFocused) {
                sidebarListView.forceActiveFocus()
                if (sidebarListView.currentItem) sidebarListView.currentItem.forceActiveFocus()
            } else {
                moveFocusToView()
            }
        }
    }
}
