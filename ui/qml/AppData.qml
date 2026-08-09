pragma Singleton
import QtQuick 2.15
import QtQml 2.15
Item {
    id: appData

    QtObject {
        id: sessionSettings
        property string category: "BigfinSessions"
        property string activeSessionId: ""
        property string savedSessionsJson: ""
    }

    // Active Theme State Singleton
    property int activeThemeIndex: 0

    // Real Live Jellyfin Server Connection State
    property string liveServerUrl: ""
    property string serverName: ""
    property string serverVersion: ""
    property string authenticatedUser: ""
    property string userId: ""
    property string accessToken: ""
    property bool isConnectedToLiveServer: false
    property bool isAuthenticated: false
    property string connectionError: ""

    signal connectionFailed(string errorMessage)
    signal connectionStatusChanged()

    // Active User Settings & Tab State
    property bool showEndsAtInSubtitle: false
    property int seasonNavModeIdx: 0
    property bool seasonNavGoesToStart: seasonNavModeIdx === 0 || seasonNavModeIdx === 2
    property bool showRatings: true
    property int ratingsCategoryIdx: 0 // 0: Movies & Shows, 1: Movies Only, 2: Shows Only, 3: All Media Types
    readonly property var ratingsCategoryOptions: ["Movies & Shows", "Movies Only", "Shows Only", "All Media Types"]
    property string activeMusicSubFilter: "songs"

    // Centralized Dedicated Music Player Engine & Queue State
    property var currentMusicTrack: null
    property var musicQueue: []
    property int musicQueueIndex: 0
    property bool isMusicPlaying: false
    property real musicPosition: 0.0
    property real musicDuration: 180.0
    property bool musicShuffle: false
    property int musicRepeatMode: 0 // 0: Off, 1: Repeat All, 2: Repeat One
    property bool isMusicPlayerActive: false
    property bool isMusicMiniPlayerVisible: currentMusicTrack !== null && !isMusicPlayerActive

    signal musicTrackChanged(var track)

    function isMusicMedia(item) {
        if (!item) return false
        var mType = (item.mediaType || item.Type || (item.rawData ? item.rawData.Type : "")).toLowerCase()
        var pType = (item.playlistType || item.PlaylistMediaType || "").toLowerCase()
        return mType === "audio" || mType === "musictrack" || mType === "musicalbum" || mType === "musicartist" || mType === "song" || pType === "audio" || !!item.artist || !!item.album
    }

    function updateMusicSubFilterForMediaItem(item) {
        if (!item) return
        var mType = (item.mediaType || item.Type || "").toLowerCase()
        var pType = (item.playlistType || item.PlaylistMediaType || "").toLowerCase()

        if (mType === "playlist" || pType === "playlist" || (pType === "audio" && mType === "playlist")) {
            activeMusicSubFilter = "playlists"
        } else if (mType === "musicartist" || mType === "artist") {
            activeMusicSubFilter = "artists"
        } else if (mType === "audio" || mType === "musictrack" || mType === "song") {
            activeMusicSubFilter = "songs"
        }
    }

    function playMusicItem(item, queueList) {
        if (!item) return
        updateMusicSubFilterForMediaItem(item)

        var queue = []
        if (queueList && queueList.length > 0) {
            queue = queueList
        } else if (item.songs && item.songs.length > 0) {
            queue = item.songs
        } else if (item.tracks && item.tracks.length > 0) {
            queue = item.tracks
        } else {
            for (var a = 0; a < artistsList.length; a++) {
                if (artistsList[a].songs) {
                    for (var s = 0; s < artistsList[a].songs.length; s++) {
                        queue.push(artistsList[a].songs[s])
                    }
                }
            }
            if (queue.length === 0) queue = [item]
        }

        var foundIdx = -1
        for (var i = 0; i < queue.length; i++) {
            if (queue[i].id === item.id || queue[i].title === item.title) {
                foundIdx = i
                break
            }
        }

        if (foundIdx === -1) {
            if (item.songs && item.songs.length > 0) {
                foundIdx = 0
                item = item.songs[0]
            } else {
                queue.unshift(item)
                foundIdx = 0
            }
        }

        musicQueue = queue
        musicQueueIndex = foundIdx
        currentMusicTrack = queue[foundIdx] ? queue[foundIdx] : item
        isMusicPlaying = true
        musicPosition = 0.0
        musicTrackChanged(currentMusicTrack)
        console.log("[MUSIC ENGINE] Playing track: " + currentMusicTrack.title + " (Index: " + musicQueueIndex + " of " + musicQueue.length + ")")
    }

    function nextMusicTrack() {
        if (!musicQueue || musicQueue.length === 0) return
        if (musicRepeatMode === 2) {
            musicPosition = 0.0
            isMusicPlaying = true
            return
        }

        var nextIdx = musicQueueIndex + 1
        if (musicShuffle) {
            nextIdx = Math.floor(Math.random() * musicQueue.length)
        } else if (nextIdx >= musicQueue.length) {
            if (musicRepeatMode === 1) {
                nextIdx = 0
            } else {
                isMusicPlaying = false
                return
            }
        }

        musicQueueIndex = nextIdx
        currentMusicTrack = musicQueue[nextIdx]
        musicPosition = 0.0
        isMusicPlaying = true
        musicTrackChanged(currentMusicTrack)
        console.log("[MUSIC ENGINE] Next track: " + currentMusicTrack.title)
    }

    function prevMusicTrack() {
        if (!musicQueue || musicQueue.length === 0) return
        var prevIdx = musicQueueIndex - 1
        if (prevIdx < 0) {
            prevIdx = musicQueue.length - 1
        }
        musicQueueIndex = prevIdx
        currentMusicTrack = musicQueue[prevIdx]
        musicPosition = 0.0
        isMusicPlaying = true
        musicTrackChanged(currentMusicTrack)
        console.log("[MUSIC ENGINE] Previous track: " + currentMusicTrack.title)
    }

    function toggleMusicPlayPause() {
        isMusicPlaying = !isMusicPlaying
    }

    function toggleMusicShuffle() {
        musicShuffle = !musicShuffle
    }

    function cycleMusicRepeatMode() {
        musicRepeatMode = (musicRepeatMode + 1) % 3
    }

    function isRatingVisible(item) {
        if (!showRatings) return false
        if (!item) return false

        var mediaType = item.mediaType || item.Type || ""
        var isMusic = (mediaType === "MusicAlbum" || mediaType === "Audio" || mediaType === "MusicArtist" || mediaType === "Playlist" || mediaType === "MusicTrack" || !!item.artist || !!item.album)

        if (isMusic && ratingsCategoryIdx !== 3) {
            return false
        }

        var isMovie = (mediaType === "Movie" || mediaType === "movie")
        var isTV = (mediaType === "Series" || mediaType === "series" || mediaType === "Episode" || mediaType === "TvProgram")

        if (ratingsCategoryIdx === 0) {
            return isMovie || isTV
        } else if (ratingsCategoryIdx === 1) {
            return isMovie
        } else if (ratingsCategoryIdx === 2) {
            return isTV
        } else if (ratingsCategoryIdx === 3) {
            return true
        }

        return isMovie || isTV
    }

    // TTL Cache Engine for UI Data Across All Screens
    property var dataCache: ({})
    property int defaultCacheTtlMs: 300000 // 5 minutes default TTL

    Timer {
        id: cacheCleanupTimer
        interval: 30000 // Run cleanup every 30 seconds
        running: true
        repeat: true
        onTriggered: appData.clearExpiredCache()
    }

    function getCachedData(key) {
        if (!dataCache || !dataCache[key]) return null
        var entry = dataCache[key]
        var now = Date.now()
        if (now - entry.timestamp < entry.ttlMs) {
            console.log("[CACHE HIT] Key: " + key + " (Age: " + Math.round((now - entry.timestamp)/1000) + "s)")
            return entry.data
        }
        console.log("[CACHE EXPIRED] Evicting key: " + key)
        delete dataCache[key]
        return null
    }

    function setCachedData(key, data, customTtlMs) {
        if (!dataCache) dataCache = {}
        var ttl = (customTtlMs !== undefined && customTtlMs !== null) ? customTtlMs : defaultCacheTtlMs
        dataCache[key] = {
            data: data,
            timestamp: Date.now(),
            ttlMs: ttl
        }
        console.log("[CACHE STORE] Saved key: " + key + " with TTL: " + Math.round(ttl/1000) + "s")
    }

    function clearExpiredCache() {
        if (!dataCache) return
        var now = Date.now()
        var evictedCount = 0
        for (var k in dataCache) {
            if (dataCache.hasOwnProperty(k)) {
                if (now - dataCache[k].timestamp >= dataCache[k].ttlMs) {
                    delete dataCache[k]
                    evictedCount++
                }
            }
        }
        if (evictedCount > 0) {
            console.log("[CACHE CLEANUP] Evicted " + evictedCount + " expired cache items.")
        }
    }

    function invalidateCacheKey(key) {
        if (dataCache && dataCache[key]) {
            delete dataCache[key]
            console.log("[CACHE INVALIDATE] Removed key: " + key)
        }
    }

    function clearAllCache() {
        dataCache = {}
        console.log("[CACHE CLEAR] Cleared entire UI data cache.")
    }

    // Saved Sessions State
    property var savedSessions: []
    property string activeSessionId: ""

    readonly property var themePalettes: [
        {
            name: "Midnight OLED Dark",
            bgStop1: "#0b0e17",
            bgStop2: "#0f172a",
            bgStop3: "#030712",
            accent: "#00f0ff",
            focusCard: "#1e293b",
            headerBg: "#080c14",
            cardBg: "#0d1322"
        },
        {
            name: "Cyberpunk Neon",
            bgStop1: "#18042c",
            bgStop2: "#2e0854",
            bgStop3: "#0d021a",
            accent: "#ff007f",
            focusCard: "#3b0764",
            headerBg: "#120224",
            cardBg: "#1f0438"
        },
        {
            name: "Deep Ocean",
            bgStop1: "#022c22",
            bgStop2: "#064e3b",
            bgStop3: "#021a12",
            accent: "#10b981",
            focusCard: "#065f46",
            headerBg: "#011c16",
            cardBg: "#02382c"
        }
    ]

    readonly property var currentTheme: themePalettes[activeThemeIndex]

    // Separate Media Category Stores
    property var moviesList: []
    property var tvShowsList: []
    property var musicList: [
        { id: "alb_1", title: "Stories from the Western Front", mediaType: "MusicAlbum", artist: "Sabaton", albumArtist: "Sabaton", subtitle: "Sabaton", year: "2023", duration: "42m", posterUrl: "assets/posters/sabaton.svg", genres: ["Power Metal", "Metal"] },
        { id: "alb_2", title: "American Pie", mediaType: "MusicAlbum", artist: "Don McLean", albumArtist: "Don McLean", subtitle: "Don McLean", year: "1971", duration: "36m", posterUrl: "assets/posters/american_pie.svg", genres: ["Folk Rock", "Pop"] }
    ]
    property var artistsList: [
        { id: "art_1", title: "Alan Menken", mediaType: "MusicArtist", subtitle: "5 Songs", posterUrl: "", songs: [
            { id: "tr_a1", title: "A Whole New World", mediaType: "Audio", artist: "Alan Menken", duration: "2m 40s" },
            { id: "tr_a2", title: "Under the Sea", mediaType: "Audio", artist: "Alan Menken", duration: "3m 15s" },
            { id: "tr_a3", title: "Beauty and the Beast", mediaType: "Audio", artist: "Alan Menken", duration: "2m 44s" },
            { id: "tr_a4", title: "Part of Your World", mediaType: "Audio", artist: "Alan Menken", duration: "3m 13s" },
            { id: "tr_a5", title: "Friend Like Me", mediaType: "Audio", artist: "Alan Menken", duration: "2m 26s" }
        ] },
        { id: "art_2", title: "Andra Day", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_ad1", title: "Rise Up", mediaType: "Audio", artist: "Andra Day", duration: "4m 13s" },
            { id: "tr_ad2", title: "Tigress & Tweed", mediaType: "Audio", artist: "Andra Day", duration: "3m 12s" },
            { id: "tr_ad3", title: "Make Your Troubles Go Away", mediaType: "Audio", artist: "Andra Day", duration: "3m 45s" }
        ] },
        { id: "art_3", title: "B.B. King", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_k1", title: "The Thrill Is Gone", mediaType: "Audio", artist: "B.B. King", duration: "5m 24s" },
            { id: "tr_k2", title: "Lucille", mediaType: "Audio", artist: "B.B. King", duration: "10m 16s" },
            { id: "tr_k3", title: "Sweet Little Angel", mediaType: "Audio", artist: "B.B. King", duration: "3m 48s" }
        ] },
        { id: "art_4", title: "Baljeet", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_bal1", title: "Gimme a Grade", mediaType: "Audio", artist: "Baljeet", duration: "2m 15s" },
            { id: "tr_bal2", title: "That's Math Magic", mediaType: "Audio", artist: "Baljeet", duration: "1m 55s" },
            { id: "tr_bal3", title: "Super Computer", mediaType: "Audio", artist: "Baljeet", duration: "2m 05s" }
        ] },
        { id: "art_5", title: "The Beatles", mediaType: "MusicArtist", subtitle: "6 Songs", posterUrl: "", songs: [
            { id: "tr_b1", title: "Here Comes the Sun", mediaType: "Audio", artist: "The Beatles", duration: "3m 05s" },
            { id: "tr_b2", title: "Hey Jude", mediaType: "Audio", artist: "The Beatles", duration: "7m 11s" },
            { id: "tr_b3", title: "Let It Be", mediaType: "Audio", artist: "The Beatles", duration: "4m 03s" },
            { id: "tr_b4", title: "Yesterday", mediaType: "Audio", artist: "The Beatles", duration: "2m 05s" },
            { id: "tr_b5", title: "Come Together", mediaType: "Audio", artist: "The Beatles", duration: "4m 19s" },
            { id: "tr_b6", title: "Eleanor Rigby", mediaType: "Audio", artist: "The Beatles", duration: "2m 06s" }
        ] },
        { id: "art_6", title: "Bénabar", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_ben1", title: "L'Effet Papillon", mediaType: "Audio", artist: "Bénabar", duration: "3m 34s" },
            { id: "tr_ben2", title: "Le Dîner", mediaType: "Audio", artist: "Bénabar", duration: "3m 02s" },
            { id: "tr_ben3", title: "Quatre Murs Et Un Toit", mediaType: "Audio", artist: "Bénabar", duration: "3m 20s" }
        ] },
        { id: "art_7", title: "Black Eyed Peas", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_bep1", title: "I Gotta Feeling", mediaType: "Audio", artist: "Black Eyed Peas", duration: "4m 49s" },
            { id: "tr_bep2", title: "Where Is the Love?", mediaType: "Audio", artist: "Black Eyed Peas", duration: "4m 42s" },
            { id: "tr_bep3", title: "Pump It", mediaType: "Audio", artist: "Black Eyed Peas", duration: "3m 33s" }
        ] },
        { id: "art_8", title: "Boney M.", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_bon1", title: "Rasputin", mediaType: "Audio", artist: "Boney M.", duration: "4m 25s" },
            { id: "tr_bon2", title: "Daddy Cool", mediaType: "Audio", artist: "Boney M.", duration: "3m 28s" },
            { id: "tr_bon3", title: "Rivers of Babylon", mediaType: "Audio", artist: "Boney M.", duration: "4m 18s" }
        ] },
        { id: "art_9", title: "Brad Paisley", mediaType: "MusicArtist", subtitle: "3 Songs", posterUrl: "", songs: [
            { id: "tr_bp1", title: "Mud on the Tires", mediaType: "Audio", artist: "Brad Paisley", duration: "3m 28s" },
            { id: "tr_bp2", title: "Whiskey Lullaby", mediaType: "Audio", artist: "Brad Paisley", duration: "4m 19s" },
            { id: "tr_bp3", title: "She's Everything", mediaType: "Audio", artist: "Brad Paisley", duration: "4m 26s" }
        ] }
    ]
    property var playlistsList: [
        {
            id: "pl_m1",
            title: "Blockbuster Movies",
            mediaType: "Playlist",
            playlistType: "Movie",
            subtitle: "4 Movies • Playlist",
            posterUrl: "assets/posters/interstellar.svg",
            poster1: "assets/posters/interstellar.svg",
            poster2: "assets/posters/bladerunner.svg",
            poster3: "assets/posters/dune2.svg"
        },
        {
            id: "pl_m2",
            title: "Sci-Fi & Action",
            mediaType: "Playlist",
            playlistType: "Movie",
            subtitle: "6 Movies • Playlist",
            posterUrl: "assets/posters/bladerunner.svg",
            poster1: "assets/posters/bladerunner.svg",
            poster2: "assets/posters/dune2.svg",
            poster3: "assets/posters/mandalorian.svg"
        },
        {
            id: "pl_m3",
            title: "Family Movie Night",
            mediaType: "Playlist",
            playlistType: "Movie",
            subtitle: "5 Movies • Playlist",
            posterUrl: "assets/posters/american_pie.svg",
            poster1: "assets/posters/american_pie.svg",
            poster2: "assets/posters/breakingbad.svg",
            poster3: "assets/posters/interstellar.svg"
        },
        {
            id: "pl_s1",
            title: "Family Playlist",
            mediaType: "Playlist",
            playlistType: "Audio",
            subtitle: "12 Songs • Playlist",
            posterUrl: "assets/posters/american_pie.svg",
            poster1: "assets/posters/american_pie.svg",
            poster2: "assets/posters/sabaton.svg",
            poster3: "assets/posters/american_pie.svg",
            poster4: "assets/posters/sabaton.svg"
        },
        {
            id: "pl_s2",
            title: "My Song List",
            mediaType: "Playlist",
            playlistType: "Audio",
            subtitle: "8 Songs • Playlist",
            posterUrl: "assets/posters/sabaton.svg",
            poster1: "assets/posters/sabaton.svg",
            poster2: "assets/posters/american_pie.svg",
            poster3: "assets/posters/sabaton.svg",
            poster4: "assets/posters/american_pie.svg"
        }
    ]
    property var favoritesList: []
    property var continueWatching: []
    property var nextUpList: []
    property var recentlyAddedMovies: []
    property var recentlyAddedMusic: []
    property var recentlyAddedShows: []
    property var mediaGrid: []
    property var searchResults: []
    property var featuredHero: null

    // Sidebar Category Menu Items (Dynamically excludes Favorites if no favorites exist)
    readonly property var sidebarCategories: {
        var items = [
            { id: "home", title: "Home", icon: "assets/icons/home.svg" },
            { id: "movies", title: "Movies", icon: "assets/icons/movies.svg" },
            { id: "tvshows", title: "Shows", icon: "assets/icons/tv.svg" },
            { id: "music", title: "Music", icon: "assets/icons/music.svg" }
        ]
        if (favoritesList && favoritesList.length > 0) {
            items.push({ id: "favorites", title: "Favorites", icon: "assets/icons/favorites.svg" })
        }
        items.push({ id: "search", title: "Search", icon: "assets/icons/search.svg" })
        items.push({ id: "settings", title: "Settings", icon: "assets/icons/settings.svg" })
        return items
    }

    Timer {
        interval: 10
        running: true
        repeat: false
        onTriggered: {
            appData.loadSavedSessions()
        }
    }

    function initSampleData() {
        clearAllMedia()
    }

    function clearAllMedia() {
        moviesList = []
        tvShowsList = []
        musicList = []
        playlistsList = []
        favoritesList = []
        continueWatching = []
        nextUpList = []
        recentlyAddedMovies = []
        recentlyAddedMusic = []
        recentlyAddedShows = []
        mediaGrid = []
        featuredHero = null
    }

    function setConnectionFailed(msg) {
        isConnectedToLiveServer = false
        isAuthenticated = false
        connectionError = msg
        clearAllMedia()
        connectionStatusChanged()
        connectionFailed(msg)
    }

    function parseIpList(input) {
        if (!input || input.trim() === "") return []
        var parts = input.split(/[,;\n\r]+/)
        var result = []
        for (var i = 0; i < parts.length; i++) {
            var token = parts[i].trim()
            if (token !== "") {
                var subTokens = token.split(/\s+/)
                for (var j = 0; j < subTokens.length; j++) {
                    var sub = subTokens[j].trim()
                    if (sub !== "") {
                        while (sub.endsWith("/")) {
                            sub = sub.substring(0, sub.length - 1)
                        }
                        if (!sub.startsWith("http://") && !sub.startsWith("https://")) {
                            sub = "http://" + sub
                        }
                        var protoIndex = sub.indexOf("://") + 3
                        var hostAndPort = sub.substring(protoIndex)
                        if (hostAndPort.indexOf(":") === -1) {
                            sub = sub + ":8096"
                        }
                        result.push(sub)
                    }
                }
            }
        }
        return result
    }

    function syncSettingsToDisk() {
        try {
            sessionSettings.activeSessionId = activeSessionId
            sessionSettings.savedSessionsJson = JSON.stringify(savedSessions)
        } catch (e) {
            console.log("[SESSIONS WARN] Failed to sync settings to disk: " + e)
        }
    }

    function readConfigFileDirectly() {
        var base = Qt.resolvedUrl(".").toString()
        var homePath = ""
        var idx = base.indexOf("/home/")
        if (idx !== -1) {
            var rest = base.substring(idx + 6)
            var slashIdx = rest.indexOf("/")
            if (slashIdx !== -1) {
                var username = rest.substring(0, slashIdx)
                homePath = "/home/" + username
            }
        }
        
        var candidates = []
        if (homePath !== "") {
            candidates.push("file://" + homePath + "/.config/bigfin/sessions.json")
        }
        
        for (var c = 0; c < candidates.length; c++) {
            try {
                var xhr = new XMLHttpRequest()
                xhr.open("GET", candidates[c], false)
                xhr.send()
                if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText && xhr.responseText.trim() !== "") {
                    var data = JSON.parse(xhr.responseText)
                    if (data && data.sessions && data.sessions.length > 0) {
                        console.log("[SESSIONS] Read session config directly from " + candidates[c])
                        return data
                    }
                }
            } catch(e) {
                console.log("[SESSIONS] Read config candidate failed: " + e)
            }
        }
        return null
    }

    function loadSavedSessions() {
        var loadedData = null

        if (typeof SessionBridge !== "undefined") {
            try {
                var jsonStr = SessionBridge.loadSessionsJson()
                loadedData = JSON.parse(jsonStr)
            } catch (e) {
                console.log("[SESSIONS WARN] SessionBridge parse fail: " + e)
            }
        }

        if (!loadedData) {
            loadedData = readConfigFileDirectly()
        }

        if (!loadedData && sessionSettings.savedSessionsJson !== "") {
            try {
                loadedData = {
                    activeSessionId: sessionSettings.activeSessionId,
                    sessions: JSON.parse(sessionSettings.savedSessionsJson)
                }
            } catch (e) {
                console.log("[SESSIONS WARN] Qt Settings parse fail: " + e)
            }
        }

        if (loadedData && loadedData.sessions && loadedData.sessions.length > 0) {
            savedSessions = loadedData.sessions
            activeSessionId = loadedData.activeSessionId || savedSessions[0].id
            console.log("[SESSIONS] Loaded " + savedSessions.length + " saved sessions. Active ID: " + activeSessionId)

            for (var i = 0; i < savedSessions.length; i++) {
                var s = savedSessions[i]
                if (s.id === activeSessionId || activeSessionId === "" || savedSessions.length === 1) {
                    activeSessionId = s.id
                    serverName = s.serverName || "Jellyfin"
                    serverVersion = s.serverVersion || ""
                    authenticatedUser = s.username || "User"
                    console.log("[SESSIONS] Auto-logging into saved session for " + s.username + " at " + s.serverUrl)
                    syncSettingsToDisk()
                    loadLiveServerItems(s.serverUrl, s.userId, s.accessToken)
                    return
                }
            }
        } else if (savedSessions && savedSessions.length > 0) {
            for (var j = 0; j < savedSessions.length; j++) {
                var sess = savedSessions[j]
                if (sess.id === activeSessionId || activeSessionId === "") {
                    activeSessionId = sess.id
                    serverName = sess.serverName
                    authenticatedUser = sess.username
                    syncSettingsToDisk()
                    loadLiveServerItems(sess.serverUrl, sess.userId, sess.accessToken)
                    return
                }
            }
        }
        setConnectionFailed("Welcome to Bigfin! Please set your Jellyfin server IP address to connect.")
    }

    function saveNewSession(sUrl, sName, sVersion, uId, uName, token, rawIps) {
        liveServerUrl = sUrl
        serverName = sName
        serverVersion = sVersion
        authenticatedUser = uName
        userId = uId
        accessToken = token

        var targetIps = (rawIps && rawIps.trim() !== "") ? rawIps : sUrl

        if (typeof SessionBridge !== "undefined") {
            SessionBridge.saveSession(targetIps, sName, sVersion, uId, uName, token)
            try {
                var jsonStr = SessionBridge.loadSessionsJson()
                var loadedData = JSON.parse(jsonStr)
                if (loadedData && loadedData.sessions) {
                    savedSessions = loadedData.sessions
                    activeSessionId = loadedData.activeSessionId || ""
                }
            } catch(e) {}
        } else {
            var newSess = {
                id: uId + "_" + Date.now(),
                serverUrl: targetIps,
                serverName: sName,
                serverVersion: sVersion,
                userId: uId,
                username: uName,
                accessToken: token
            }
            var updated = []
            for (var i = 0; i < savedSessions.length; i++) {
                if (savedSessions[i].userId !== uId || savedSessions[i].serverUrl !== targetIps) {
                    updated.push(savedSessions[i])
                }
            }
            updated.unshift(newSess)
            savedSessions = updated
            activeSessionId = newSess.id
        }
        syncSettingsToDisk()
        loadLiveServerItems(targetIps, uId, token)
    }

    function switchToSession(sessId) {
        if (typeof SessionBridge !== "undefined") {
            var success = SessionBridge.switchSession(sessId)
            if (success) {
                loadSavedSessions()
                return
            }
        }
        for (var i = 0; i < savedSessions.length; i++) {
            if (savedSessions[i].id === sessId) {
                var s = savedSessions[i]
                activeSessionId = sessId
                serverName = s.serverName
                authenticatedUser = s.username
                syncSettingsToDisk()
                loadLiveServerItems(s.serverUrl, s.userId, s.accessToken)
                break
            }
        }
    }

    function deleteSession(sessId) {
        if (typeof SessionBridge !== "undefined") {
            SessionBridge.deleteSession(sessId)
            loadSavedSessions()
            return
        }
        var filtered = []
        for (var i = 0; i < savedSessions.length; i++) {
            if (savedSessions[i].id !== sessId) filtered.push(savedSessions[i])
        }
        savedSessions = filtered
        if (activeSessionId === sessId) {
            activeSessionId = filtered.length > 0 ? filtered[0].id : ""
            if (activeSessionId === "") {
                syncSettingsToDisk()
                setConnectionFailed("Session deleted. Please connect to a Jellyfin server.")
                return
            }
        }
        syncSettingsToDisk()
        loadSavedSessions()
    }

    function logoutCurrentSession() {
        if (typeof SessionBridge !== "undefined") {
            SessionBridge.logoutActiveSession()
        }
        activeSessionId = ""
        syncSettingsToDisk()
        setConnectionFailed("Logged out. Please sign in to your Jellyfin server.")
    }

    // Master function to trigger all specific category fetches after verifying server connection
    function loadLiveServerItems(baseUrl, uId, token) {
        userId = uId
        accessToken = token
        connectionError = ""

        var candidates = parseIpList(baseUrl)
        if (candidates.length === 0) {
            setConnectionFailed("No valid Jellyfin server IP specified.")
            return
        }

        tryVerifyNextIp(candidates, 0, uId, token)
    }

    function tryVerifyNextIp(candidates, index, uId, token) {
        if (index >= candidates.length) {
            var errStr = "Unable to connect to Jellyfin server at any configured IP address (" + candidates.join(", ") + "). Check server URL & network connection."
            console.log("[JELLYFIN API ERROR] " + errStr)
            setConnectionFailed(errStr)
            return
        }

        var currentUrl = candidates[index]
        console.log("[JELLYFIN API] Verifying candidate IP " + (index + 1) + "/" + candidates.length + ": GET " + currentUrl + "/System/Info/Public")

        var verifyXhr = new XMLHttpRequest()
        verifyXhr.open("GET", currentUrl + "/System/Info/Public")
        verifyXhr.timeout = 4000

        verifyXhr.onreadystatechange = function() {
            if (verifyXhr.readyState === XMLHttpRequest.DONE) {
                if (verifyXhr.status === 200) {
                    try {
                        var res = JSON.parse(verifyXhr.responseText)
                        serverName = res.ServerName || serverName || "Jellyfin Server"
                        serverVersion = res.Version || serverVersion || ""
                    } catch (e) {}

                    liveServerUrl = currentUrl
                    console.log("[JELLYFIN API SUCCESS] Server verified at " + currentUrl)
                    isConnectedToLiveServer = true
                    isAuthenticated = true
                    connectionError = ""
                    connectionStatusChanged()

                    fetchMovies()
                    fetchTVShows()
                    fetchMusic()
                    fetchPlaylists()
                    fetchFavorites()
                    fetchContinueWatching()
                    fetchNextUpList()
                    fetchRecentlyAdded()
                } else {
                    console.log("[JELLYFIN API WARN] IP candidate " + currentUrl + " returned status " + verifyXhr.status)
                    tryVerifyNextIp(candidates, index + 1, uId, token)
                }
            }
        }

        verifyXhr.ontimeout = function() {
            console.log("[JELLYFIN API WARN] IP candidate " + currentUrl + " timed out")
            tryVerifyNextIp(candidates, index + 1, uId, token)
        }

        verifyXhr.onerror = function() {
            console.log("[JELLYFIN API WARN] Network error connecting to IP candidate " + currentUrl)
            tryVerifyNextIp(candidates, index + 1, uId, token)
        }

        verifyXhr.send()
    }

    function parseJellyfinItems(items) {
        var result = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            
            var isEpisode = (item.Type === "Episode")
            var isSeries = (item.Type === "Series" || item.Type === "TvShow" || item.Type === "Show")
            var isSeason = (item.Type === "Season")
            var isPlaylist = (item.Type === "Playlist")
            var isMusic = (item.Type === "MusicAlbum" || item.Type === "Audio" || item.Type === "MusicArtist" || item.Type === "Playlist" || item.Type === "MusicTrack")
            var displayTitle = isEpisode ? (item.SeriesName || item.Name || "Untitled") : (item.Name || "Untitled")
            
            var sNum = item.ParentIndexNumber !== undefined ? item.ParentIndexNumber : (item.IndexNumber !== undefined && isSeason ? item.IndexNumber : "")
            var eNum = isEpisode && item.IndexNumber !== undefined ? item.IndexNumber : ""
            
            var epCode = ""
            if (sNum !== "" && eNum !== "") {
                epCode = "S" + sNum + ":E" + eNum
            } else if (sNum !== "") {
                epCode = "S" + sNum
            } else if (eNum !== "") {
                epCode = "E" + eNum
            }

            var childCount = item.ChildCount !== undefined ? item.ChildCount : (item.SeasonCount !== undefined ? item.SeasonCount : 0)
            var recursiveItemCount = item.RecursiveItemCount !== undefined ? item.RecursiveItemCount : (item.EpisodeCount !== undefined ? item.EpisodeCount : 0)
            var sCountStr = childCount > 0 ? (childCount + (childCount === 1 ? " Season" : " Seasons")) : ""
            var eCountStr = recursiveItemCount > 0 ? (recursiveItemCount + (recursiveItemCount === 1 ? " Episode" : " Episodes")) : ""
            var seasonsEpisodesStr = (sCountStr && eCountStr) ? (sCountStr + " • " + eCountStr) : (sCountStr || eCountStr)
            
            var displaySubtitle = ""
            if (isEpisode) {
                displaySubtitle = epCode !== "" ? (epCode + (item.Name ? (" - " + item.Name) : "")) : (item.Name || "")
            } else if (isSeries) {
                displaySubtitle = seasonsEpisodesStr !== "" ? seasonsEpisodesStr : (item.ProductionYear ? String(item.ProductionYear) : "Series")
            } else if (isSeason) {
                displaySubtitle = (sNum !== "" ? ("Season " + sNum) : item.Name) + (childCount > 0 ? (" • " + childCount + " Episodes") : "")
            } else if (isPlaylist) {
                displaySubtitle = item.ChildCount ? (item.ChildCount + " Songs • Playlist") : "Playlist"
            } else if (isMusic) {
                if (item.Type === "MusicArtist") {
                    var sCnt = childCount || recursiveItemCount || (item.SongCount || 0)
                    displaySubtitle = sCnt > 0 ? (sCnt + " Songs") : "Songs"
                } else if (item.AlbumArtist) {
                    displaySubtitle = item.AlbumArtist
                } else if (item.Artists && item.Artists.length > 0) {
                    displaySubtitle = item.Artists.join(" / ")
                } else if (item.ArtistItems && item.ArtistItems.length > 0) {
                    var artistNames = []
                    for (var a = 0; a < item.ArtistItems.length; a++) artistNames.push(item.ArtistItems[a].Name)
                    displaySubtitle = artistNames.join(" / ")
                } else {
                    displaySubtitle = item.ProductionYear ? String(item.ProductionYear) : "Music"
                }
            } else {
                displaySubtitle = item.ProductionYear ? String(item.ProductionYear) : ""
            }

            // Lightweight WebP Image Hierarchy with optimized quality & dimensions
            var poster = liveServerUrl + "/Items/" + item.Id + "/Images/Primary?fillWidth=400&quality=80&format=WEBP"
            if (isEpisode && item.SeasonId) {
                poster = liveServerUrl + "/Items/" + item.SeasonId + "/Images/Primary?fillWidth=400&quality=80&format=WEBP"
            }

            var epThumb = liveServerUrl + "/Items/" + item.Id + "/Images/Primary?fillWidth=500&quality=80&format=WEBP"

            var backdrop = poster
            if (item.BackdropImageTags && item.BackdropImageTags.length > 0) {
                backdrop = liveServerUrl + "/Items/" + item.Id + "/Images/Backdrop?fillWidth=960&quality=80&format=WEBP"
            } else if (item.ParentBackdropImageTags && item.ParentBackdropImageTags.length > 0 && item.ParentBackdropItemId) {
                backdrop = liveServerUrl + "/Items/" + item.ParentBackdropItemId + "/Images/Backdrop?fillWidth=960&quality=80&format=WEBP"
            } else if (item.SeriesId) {
                backdrop = liveServerUrl + "/Items/" + item.SeriesId + "/Images/Backdrop?fillWidth=960&quality=80&format=WEBP"
            }

            if (typeof SessionBridge !== "undefined" && SessionBridge.getCachedImage) {
                poster = SessionBridge.getCachedImage(poster)
                backdrop = SessionBridge.getCachedImage(backdrop)
                epThumb = SessionBridge.getCachedImage(epThumb)
            }

            // Official Rating (e.g. TV-Y7, TV-14, PG-13)
            var officialRating = item.OfficialRating || ""

            // Studios (e.g. Netflix, HBO)
            var studioStr = ""
            if (item.Studios && item.Studios.length > 0) {
                var studioNames = []
                for (var st = 0; st < item.Studios.length; st++) {
                    studioNames.push(item.Studios[st].Name || item.Studios[st])
                }
                studioStr = studioNames.join(", ")
            }

            // Tags (e.g. martial arts, ninja, lego...)
            var tagsStr = ""
            if (item.Tags && item.Tags.length > 0) {
                tagsStr = item.Tags.join(", ")
            }

            // External Links (IMDb, TMDB)
            var externalUrls = []
            if (item.ExternalUrls && item.ExternalUrls.length > 0) {
                for (var ex = 0; ex < item.ExternalUrls.length; ex++) {
                    externalUrls.push({ name: item.ExternalUrls[ex].Name || "Link", url: item.ExternalUrls[ex].Url || "" })
                }
            } else if (item.ProviderIds) {
                if (item.ProviderIds.Imdb) externalUrls.push({ name: "IMDb", url: "https://www.imdb.com/title/" + item.ProviderIds.Imdb })
                if (item.ProviderIds.Tmdb) externalUrls.push({ name: "TMDB", url: "https://www.themoviedb.org/movie/" + item.ProviderIds.Tmdb })
            }
            if (externalUrls.length === 0) {
                externalUrls = [{ name: "IMDb", url: "#" }, { name: "TMDB", url: "#" }]
            }

            // Cast & Crew People
            var peopleList = []
            if (item.People && Array.isArray(item.People)) {
                for (var p = 0; p < item.People.length; p++) {
                    var person = item.People[p]
                    var pImg = ""
                    if (person.Id) {
                        pImg = liveServerUrl + "/Items/" + person.Id + "/Images/Primary?fillWidth=200&quality=80&format=WEBP"
                    } else if (person.Name) {
                        pImg = liveServerUrl + "/Persons/" + encodeURIComponent(person.Name) + "/Images/Primary?fillWidth=200&quality=80&format=WEBP"
                    }
                    peopleList.push({
                        name: person.Name || "Actor",
                        role: person.Role || person.Type || "Cast",
                        type: person.Type || "Actor",
                        imageUrl: pImg
                    })
                }
            }

            // Media Specs (Video, Audio, Subtitles)
            var videoSpec = "1080p H264 SDR"
            var audioSpec = "English - Dolby Digital+ - 5.1 - Default"
            var subtitlesSpec = ["Off", "English (srt)", "Spanish"]

            if (item.MediaSources && item.MediaSources.length > 0) {
                var ms = item.MediaSources[0]
                if (ms.MediaStreams) {
                    var vSt = null, aSt = null, subSts = []
                    for (var s = 0; s < ms.MediaStreams.length; s++) {
                        var stream = ms.MediaStreams[s]
                        if (stream.Type === "Video" && !vSt) vSt = stream
                        if (stream.Type === "Audio" && (!aSt || stream.IsDefault)) aSt = stream
                        if (stream.Type === "Subtitle") subSts.push(stream.DisplayTitle || stream.Language || ("Subtitle " + (s+1)))
                    }
                    if (vSt) {
                        var h = vSt.Height ? (vSt.Height + "p") : "1080p"
                        var c = vSt.Codec ? vSt.Codec.toUpperCase() : "H264"
                        var r = vSt.VideoRange ? vSt.VideoRange.toUpperCase() : "SDR"
                        videoSpec = h + " " + c + " " + r
                    }
                    if (aSt) {
                        var l = aSt.Language ? aSt.Language.toUpperCase() : "ENG"
                        var dt = aSt.DisplayTitle || (aSt.Codec ? aSt.Codec.toUpperCase() : "AAC")
                        var chLayout = aSt.ChannelLayout || (aSt.Channels ? (aSt.Channels + "ch") : "5.1")
                        audioSpec = dt + " (" + l + " " + chLayout + ")"
                    }
                    if (subSts.length > 0) subtitlesSpec = subSts
                }
            }

            result.push({
                id: item.Id,
                title: displayTitle,
                subtitle: displaySubtitle,
                epCode: epCode,
                seasonsEpisodesStr: seasonsEpisodesStr,
                episodeName: item.Name || "",
                seriesName: item.SeriesName || "",
                seriesId: item.SeriesId || "",
                seasonId: item.SeasonId || "",
                seasonNumber: sNum,
                episodeNumber: eNum,
                mediaType: item.Type || "Movie",
                playlistType: item.PlaylistMediaType || item.MediaType || (item.Type === "Playlist" ? "Audio" : ""),
                year: item.ProductionYear ? String(item.ProductionYear) : "2024",
                rating: item.CommunityRating ? item.CommunityRating.toFixed(1) : "8.5",
                duration: item.RunTimeTicks ? Math.round(item.RunTimeTicks / 600000000) + "m" : (isMusic ? "3m 45s" : "22m"),
                overview: item.Overview || (isMusic ? (item.Type === "MusicArtist" ? "Music Artist" : "Jellyfin music collection") : "Jellyfin media stream"),
                posterUrl: poster,
                backdropUrl: backdrop,
                thumbUrl: isEpisode ? epThumb : backdrop,
                genres: (item.Genres && item.Genres.length > 0) ? item.Genres : (isMusic ? ["Music"] : ["Animation", "Action", "Adventure"]),
                isFavorite: item.UserData ? item.UserData.IsFavorite : false,
                isPlayed: item.UserData ? item.UserData.Played : false,
                progress: (item.UserData && item.UserData.PlayedPercentage) ? (item.UserData.PlayedPercentage / 100) : 0,
                officialRating: officialRating,
                studio: studioStr,
                tags: tagsStr,
                externalUrls: externalUrls,
                people: peopleList,
                videoSpec: isMusic ? "" : videoSpec,
                audioSpec: isMusic ? (item.MediaSources && item.MediaSources.length > 0 ? audioSpec : "Audio Stream") : audioSpec,
                subtitlesSpec: isMusic ? [] : subtitlesSpec,
                premiereDate: item.PremiereDate ? item.PremiereDate.substring(0, 10) : "",
                childCount: childCount,
                recursiveItemCount: recursiveItemCount,
                rawData: item
            })
        }
        return result
    }

    function fetchSeasons(seriesId, callback) {
        function returnDefaultSeasons() {
            if (callback) callback([])
        }

        if (!liveServerUrl || !userId || !seriesId) {
            console.log("[JELLYFIN API] fetchSeasons skipped (ServerURL: " + liveServerUrl + ", UserID: " + userId + ", SeriesID: " + seriesId + ")")
            returnDefaultSeasons()
            return
        }

        var cacheKey = "seasons_" + seriesId
        var cached = getCachedData(cacheKey)
        if (cached) {
            if (callback) callback(cached)
            return
        }

        console.log("[JELLYFIN API] Fetching Seasons for Series ID: " + seriesId)
        
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + seriesId + "&IncludeItemTypes=Season&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
        console.log("[JELLYFIN REQ] GET " + url)
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[JELLYFIN RESP] HTTP " + xhr.status + " for URL: " + url)
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var seasons = parseJellyfinItems(res.Items || [])
                        console.log("[JELLYFIN API SUCCESS] Seasons returned via ParentId: " + seasons.length)
                        if (seasons.length > 0) {
                            setCachedData(cacheKey, seasons, 600000)
                            if (callback) callback(seasons)
                            return
                        }
                    } catch (e) {
                        console.log("[JELLYFIN API ERROR] Failed to parse seasons JSON: " + e)
                    }
                }
                
                var xhr2 = new XMLHttpRequest()
                var url2 = liveServerUrl + "/Shows/" + seriesId + "/Seasons?UserId=" + userId + "&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
                console.log("[JELLYFIN REQ] GET Fallback " + url2)
                xhr2.open("GET", url2)
                xhr2.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                xhr2.onreadystatechange = function() {
                    if (xhr2.readyState === XMLHttpRequest.DONE) {
                        console.log("[JELLYFIN RESP] HTTP " + xhr2.status + " for URL: " + url2)
                        if (xhr2.status === 200) {
                            try {
                                var res2 = JSON.parse(xhr2.responseText)
                                var seasons2 = parseJellyfinItems(res2.Items || [])
                                console.log("[JELLYFIN API SUCCESS] Seasons returned via /Shows: " + seasons2.length)
                                if (seasons2.length > 0) {
                                    setCachedData(cacheKey, seasons2, 600000)
                                    if (callback) callback(seasons2)
                                    return
                                }
                            } catch (e) {
                                console.log("[JELLYFIN API ERROR] Failed to parse seasons JSON (fallback): " + e)
                            }
                        }
                        
                        var xhr3 = new XMLHttpRequest()
                        var url3 = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + seriesId + "&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
                        console.log("[JELLYFIN REQ] GET Fallback3 " + url3)
                        xhr3.open("GET", url3)
                        xhr3.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                        xhr3.onreadystatechange = function() {
                            if (xhr3.readyState === XMLHttpRequest.DONE) {
                                console.log("[JELLYFIN RESP] HTTP " + xhr3.status + " for URL: " + url3)
                                if (xhr3.status === 200) {
                                    try {
                                        var res3 = JSON.parse(xhr3.responseText)
                                        var seasons3 = parseJellyfinItems(res3.Items || [])
                                        console.log("[JELLYFIN API SUCCESS] Seasons returned via ParentId (fallback3): " + seasons3.length)
                                        if (seasons3.length > 0) {
                                            setCachedData(cacheKey, seasons3, 600000)
                                            if (callback) callback(seasons3)
                                            return
                                        }
                                    } catch (e) {}
                                }
                                returnDefaultSeasons()
                            }
                        }
                        xhr3.send()
                    }
                }
                xhr2.send()
            }
        }
        xhr.send()
    }

    function fetchEpisodes(seriesId, seasonId, callback) {
        function returnDefaultEpisodes() {
            if (callback) callback([])
        }

        if (!liveServerUrl || !userId || !seriesId) {
            console.log("[JELLYFIN API] fetchEpisodes skipped (ServerURL: " + liveServerUrl + ", UserID: " + userId + ", SeriesID: " + seriesId + ")")
            returnDefaultEpisodes()
            return
        }

        var cacheKey = "episodes_" + seriesId + "_" + (seasonId || "all")
        var cached = getCachedData(cacheKey)
        if (cached) {
            if (callback) callback(cached)
            return
        }

        console.log("[JELLYFIN API] Fetching episodes for Series ID: " + seriesId + " | Season ID: " + seasonId)

        var targetParent = seasonId ? seasonId : seriesId
        
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Shows/" + seriesId + "/Episodes?UserId=" + userId + (seasonId ? ("&SeasonId=" + seasonId) : "") + "&Fields=ParentIndexNumber,IndexNumber,IndexNumberEnd,PrimaryImageAspectRatio,Overview,MediaSources,UserData,People,Studios,Tags,OfficialRating,ExternalUrls,ProviderIds,PremiereDate"
        console.log("[JELLYFIN REQ] GET " + url)
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[JELLYFIN RESP] HTTP " + xhr.status + " for URL: " + url)
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var episodes = parseJellyfinItems(res.Items || [])
                        console.log("[JELLYFIN API SUCCESS] Episodes returned via /Shows: " + episodes.length)
                        if (episodes.length > 0) {
                            setCachedData(cacheKey, episodes, 600000)
                            if (callback) callback(episodes)
                            return
                        }
                    } catch (e) {
                        console.log("[JELLYFIN API ERROR] Failed to parse episodes JSON: " + e)
                    }
                }

                var xhr2 = new XMLHttpRequest()
                var url2 = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + targetParent + "&IncludeItemTypes=Episode" + (seasonId ? "" : "&Recursive=true") + "&Fields=ParentIndexNumber,IndexNumber,IndexNumberEnd,PrimaryImageAspectRatio,Overview,MediaSources,UserData,SeriesName,SeriesId,SeasonId,People,Studios,Tags,OfficialRating,ExternalUrls,ProviderIds,PremiereDate"
                console.log("[JELLYFIN REQ] GET Fallback " + url2)
                xhr2.open("GET", url2)
                xhr2.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                xhr2.onreadystatechange = function() {
                    if (xhr2.readyState === XMLHttpRequest.DONE) {
                        console.log("[JELLYFIN RESP] HTTP " + xhr2.status + " for URL: " + url2)
                        if (xhr2.status === 200) {
                            try {
                                var res2 = JSON.parse(xhr2.responseText)
                                var episodes2 = parseJellyfinItems(res2.Items || [])
                                console.log("[JELLYFIN API SUCCESS] Episodes returned via ParentId: " + episodes2.length)
                                if (episodes2.length > 0) {
                                    setCachedData(cacheKey, episodes2, 600000)
                                    if (callback) callback(episodes2)
                                    return
                                }
                            } catch (e) {
                                console.log("[JELLYFIN API ERROR] Failed to parse episodes JSON (fallback): " + e)
                            }
                        }
                        
                        returnDefaultEpisodes()
                    }
                }
                xhr2.send()
            }
        }
        xhr.send()
    }

    function fetchNextUpForSeries(seriesId, callback) {
        function returnDefaultNextUp() {
            if (callback) callback(null)
        }

        if (!liveServerUrl || !userId) {
            returnDefaultNextUp()
            return
        }

        var cacheKey = "next_up_" + seriesId
        var cached = getCachedData(cacheKey)
        if (cached !== null) {
            if (callback) callback(cached)
            return
        }

        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Shows/NextUp?UserId=" + userId + "&SeriesId=" + seriesId + "&Fields=PrimaryImageAspectRatio,Overview,MediaSources,UserData"
        console.log("[JELLYFIN REQ] GET NextUp: " + url)
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                console.log("[JELLYFIN RESP] HTTP " + xhr.status + " for NextUp")
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var items = parseJellyfinItems(res.Items || [])
                        console.log("[JELLYFIN API SUCCESS] NextUp items returned: " + items.length)
                        if (items.length > 0) {
                            setCachedData(cacheKey, items[0], 180000)
                            if (callback) callback(items[0])
                            return
                        }
                    } catch (e) {}
                }
                returnDefaultNextUp()
            }
        }
        xhr.send()
    }

    function fetchMovies() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("movies")
        if (cached) {
            moviesList = cached
            if (cached.length > 0 && !featuredHero) {
                featuredHero = cached[0]
                featuredHero.quality = "4K Direct Stream"
            }
            updateMasterGrid()
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Movie&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData&Limit=100"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    moviesList = parsed
                    setCachedData("movies", parsed, 300000)
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " MOVIES")
                    
                    if (parsed.length > 0) {
                        if (!featuredHero) {
                            featuredHero = parsed[0]
                            featuredHero.quality = "4K Direct Stream"
                        }
                    }
                    updateMasterGrid()
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Movies parse fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchTVShows() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("tvshows")
        if (cached) {
            tvShowsList = cached
            updateMasterGrid()
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Series&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,ChildCount,RecursiveItemCount,ParentIndexNumber,IndexNumber,SeriesName,SeriesId,SeasonId&Limit=100"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    tvShowsList = parsed
                    setCachedData("tvshows", parsed, 300000)
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " TV SHOWS")
                    updateMasterGrid()
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] TV Shows parse fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchFavorites() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("favorites")
        if (cached) {
            favoritesList = cached
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?Filters=IsFavorite&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData&Limit=100"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    favoritesList = parsed
                    setCachedData("favorites", parsed, 180000)
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " FAVORITES")
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Favorites parse fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchContinueWatching() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("continue_watching")
        if (cached) {
            continueWatching = cached
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items/Resume?Limit=30&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,SeriesId,SeriesName,ChildCount,RecursiveItemCount,ParentIndexNumber,IndexNumber,SeasonId"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var rawItems = res.Items || []
                    var deduplicated = []
                    var seenShows = {}

                    for (var k = 0; k < rawItems.length; k++) {
                        var raw = rawItems[k]
                        var showKey = raw.SeriesId || raw.SeriesName || raw.Id
                        if (showKey) {
                            if (seenShows[showKey]) continue
                            seenShows[showKey] = true
                        }
                        deduplicated.push(raw)
                    }

                    var parsed = parseJellyfinItems(deduplicated)
                    for (var i = 0; i < parsed.length; i++) {
                        if (!parsed[i].subtitle) parsed[i].subtitle = "Resume Playback"
                        parsed[i].timeLeft = "In Progress"
                    }
                    continueWatching = parsed
                    setCachedData("continue_watching", parsed, 120000)
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " deduplicated CONTINUE WATCHING items (1 per show)")
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Continue watching fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchNextUpList() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("next_up_list")
        if (cached) {
            nextUpList = cached
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Shows/NextUp?UserId=" + userId + "&Limit=25&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,SeriesId,SeriesName,ChildCount,RecursiveItemCount,ParentIndexNumber,IndexNumber,SeasonId"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    for (var i = 0; i < parsed.length; i++) {
                        if (!parsed[i].subtitle) parsed[i].subtitle = "Next Up"
                        parsed[i].timeLeft = "Next Up"
                    }
                    nextUpList = parsed
                    setCachedData("next_up_list", parsed, 120000)
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " NEXT UP episodes")
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Next Up parse fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchPlaylists() {
        if (!liveServerUrl || !userId) return
        var cached = getCachedData("playlists")
        if (cached && cached.length > 0) {
            playlistsList = cached
            updateMasterGrid()
        }

        var xhrPl = new XMLHttpRequest()
        var urlPl = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Playlist&Recursive=true&Fields=PrimaryImageAspectRatio,Overview,ChildCount,MediaType,PlaylistMediaType"
        xhrPl.open("GET", urlPl)
        xhrPl.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhrPl.onreadystatechange = function() {
            if (xhrPl.readyState === XMLHttpRequest.DONE && xhrPl.status === 200) {
                try {
                    var resPl = JSON.parse(xhrPl.responseText)
                    var rawPl = resPl.Items || (Array.isArray(resPl) ? resPl : [])
                    var parsedPl = parseJellyfinItems(rawPl)
                    playlistsList = parsedPl
                    setCachedData("playlists", playlistsList, 300000)
                    console.log("[JELLYFIN API] Playlists endpoint loaded " + parsedPl.length + " playlists from Jellyfin")
                    updateMasterGrid()
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Playlists endpoint fail: " + e)
                }
            }
        }
        xhrPl.send()
    }

    function fetchMusic() {
        if (!liveServerUrl || !userId) return
        fetchPlaylists()
        var cached = getCachedData("music")
        if (cached) {
            musicList = cached
            updateMasterGrid()
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Playlist,MusicAlbum,Audio,MusicArtist&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount,MediaType,PlaylistMediaType&Limit=100"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    
                    var playlists = []
                    var nonPlaylists = []
                    for (var i = 0; i < parsed.length; i++) {
                        if (parsed[i].mediaType === "Playlist" || parsed[i].Type === "Playlist") {
                            playlists.push(parsed[i])
                        } else {
                            nonPlaylists.push(parsed[i])
                        }
                    }
                    if (playlists.length > 0) {
                        playlistsList = playlists
                        setCachedData("playlists", playlistsList, 300000)
                    }
                    musicList = playlists.concat(nonPlaylists)
                    setCachedData("music", musicList, 300000)
                    console.log("[JELLYFIN API] Loaded " + playlists.length + " Playlists and " + nonPlaylists.length + " Music items")
                    updateMasterGrid()
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Music parse fail: " + e)
                }
            }
        }
        xhr.send()

        // Dedicated query for Jellyfin Artists
        var xhrArt = new XMLHttpRequest()
        var urlArt = liveServerUrl + "/Artists?UserId=" + userId + "&Fields=PrimaryImageAspectRatio,Overview,Genres"
        xhrArt.open("GET", urlArt)
        xhrArt.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhrArt.onreadystatechange = function() {
            if (xhrArt.readyState === XMLHttpRequest.DONE && xhrArt.status === 200) {
                try {
                    var resArt = JSON.parse(xhrArt.responseText)
                    var rawArt = resArt.Items || (Array.isArray(resArt) ? resArt : [])
                    if (rawArt.length > 0) {
                        var parsedArt = parseJellyfinItems(rawArt)
                        artistsList = parsedArt
                        setCachedData("artists", parsedArt, 300000)
                        console.log("[JELLYFIN API] Loaded " + parsedArt.length + " Artists from Jellyfin")
                    }
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Artists endpoint fail: " + e)
                }
            }
        }
        xhrArt.send()
    }

    function fetchPlaylistItems(playlistId, callback) {
        if (!liveServerUrl || !userId || !playlistId) {
            if (callback) callback([])
            return
        }
        var cached = getCachedData("playlist_" + playlistId)
        if (cached && cached.length > 0) {
            if (callback) callback(cached)
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Playlists/" + playlistId + "/Items?userId=" + userId + "&UserId=" + userId + "&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var rawItems = res.Items || (Array.isArray(res) ? res : [])
                        if (rawItems.length > 0) {
                            var parsed = parseJellyfinItems(rawItems)
                            setCachedData("playlist_" + playlistId, parsed, 300000)
                            console.log("[JELLYFIN API SUCCESS] Playlist items loaded from Jellyfin for " + playlistId + ": " + parsed.length)
                            if (callback) callback(parsed)
                            return
                        }
                    } catch (e) {
                        console.log("[JELLYFIN API ERROR] Playlist items parse fail: " + e)
                    }
                }
                fetchItemsByParentId(playlistId, callback)
            }
        }
        xhr.send()
    }

    function fetchItemsByParentId(parentId, callback) {
        if (!liveServerUrl || !userId || !parentId) {
            if (callback) callback([])
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + parentId + "&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var rawItems = res.Items || (Array.isArray(res) ? res : [])
                        if (rawItems.length > 0) {
                            var parsed = parseJellyfinItems(rawItems)
                            setCachedData("playlist_" + parentId, parsed, 300000)
                            console.log("[JELLYFIN API SUCCESS] Items loaded via ParentId for " + parentId + ": " + parsed.length)
                            if (callback) callback(parsed)
                            return
                        }
                    } catch (e) {
                        console.log("[JELLYFIN API ERROR] ParentId query parse fail: " + e)
                    }
                }
                fetchItemsByParentIdDirect(parentId, callback)
            }
        }
        xhr.send()
    }

    function fetchItemsByParentIdDirect(parentId, callback) {
        if (!liveServerUrl || !userId || !parentId) {
            if (callback) callback([])
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Items?ParentId=" + parentId + "&UserId=" + userId + "&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var rawItems = res.Items || (Array.isArray(res) ? res : [])
                        if (rawItems.length > 0) {
                            var parsed = parseJellyfinItems(rawItems)
                            setCachedData("playlist_" + parentId, parsed, 300000)
                            console.log("[JELLYFIN API SUCCESS] Direct ParentId loaded " + parsed.length + " items for " + parentId)
                            if (callback) callback(parsed)
                            return
                        }
                    } catch (e) {
                        console.log("[JELLYFIN API ERROR] Direct ParentId parse fail: " + e)
                    }
                }
                if (callback) callback([])
            }
        }
        xhr.send()
    }

    function fetchRecentlyAdded() {
        if (!liveServerUrl || !userId) return
        fetchRecentlyAddedCategory("Movie", function(items) { if (items.length > 0) recentlyAddedMovies = items })
        fetchRecentlyAddedCategory("MusicAlbum", function(items) { if (items.length > 0) recentlyAddedMusic = items })
        fetchRecentlyAddedCategory("Series", function(items) { if (items.length > 0) recentlyAddedShows = items })
    }

    function fetchRecentlyAddedCategory(itemType, callback) {
        var cacheKey = "recently_added_" + itemType
        var cached = getCachedData(cacheKey)
        if (cached) {
            if (callback) callback(cached)
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items/Latest?IncludeItemTypes=" + itemType + "&Limit=16&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount,RecursiveItemCount,ParentIndexNumber,IndexNumber,SeriesName,SeriesId,SeasonId"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var rawItems = Array.isArray(res) ? res : (res.Items || [])
                    var parsed = parseJellyfinItems(rawItems)
                    setCachedData(cacheKey, parsed, 300000)
                    if (callback) callback(parsed)
                } catch (e) {
                    if (callback) callback([])
                }
            }
        }
        xhr.send()
    }

    function updateMasterGrid() {
        var combined = []
        for (var i = 0; i < moviesList.length; i++) combined.push(moviesList[i])
        for (var j = 0; j < tvShowsList.length; j++) combined.push(tvShowsList[j])
        for (var k = 0; k < musicList.length; k++) combined.push(musicList[k])
        mediaGrid = combined
    }

    function fetchArtistItems(artistId, callback) {
        if (!liveServerUrl || !userId || !artistId) {
            if (callback) callback([])
            return
        }
        var cacheKey = "artist_items_" + artistId
        var cached = getCachedData(cacheKey)
        if (cached) {
            if (callback) callback(cached)
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?ArtistIds=" + artistId + "&IncludeItemTypes=Audio&Recursive=true&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var rawItems = res.Items || (Array.isArray(res) ? res : [])
                    var parsed = parseJellyfinItems(rawItems)
                    setCachedData(cacheKey, parsed, 300000)
                    if (callback) callback(parsed)
                } catch (e) {
                    if (callback) callback([])
                }
            }
        }
        xhr.send()
    }

    function searchJellyfin(query, callback) {
        if (!liveServerUrl || !userId) return
        var cacheKey = "search_" + query.toLowerCase().trim()
        var cached = getCachedData(cacheKey)
        if (cached) {
            searchResults = cached
            if (callback) callback(cached)
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?SearchTerm=" + encodeURIComponent(query) + "&IncludeItemTypes=Movie,Series,Episode,Audio,MusicAlbum,MusicArtist,Playlist&Fields=PrimaryImageAspectRatio,Overview,CommunityRating,RunTimeTicks,ProductionYear,ChildCount,RecursiveItemCount,ParentIndexNumber,IndexNumber,SeriesName,SeriesId,SeasonId&Limit=40"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var results = parseJellyfinItems(res.Items || [])
                    searchResults = results
                    setCachedData(cacheKey, results, 120000)
                    if (callback) callback(results)
                } catch (e) {}
            }
        }
        xhr.send()
    }

    function toggleFavorite(itemId, isFavorite, callback) {
        if (!liveServerUrl || !userId) return
        var method = isFavorite ? "POST" : "DELETE"
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/FavoriteItems/" + itemId
        xhr.open(method, url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    invalidateCacheKey("favorites")
                    invalidateCacheKey("movies")
                    invalidateCacheKey("tvshows")
                    fetchFavorites()
                }
                if (callback) callback(xhr.status === 200)
            }
        }
        xhr.send()
    }

    function reportPlaybackStart(itemId, posSeconds) {
        if (!itemId) return
        if (typeof SessionBridge !== "undefined" && liveServerUrl && accessToken) {
            SessionBridge.reportPlaybackStart(liveServerUrl, accessToken, itemId, posSeconds || 0)
        } else if (liveServerUrl && accessToken) {
            var xhr = new XMLHttpRequest()
            var url = liveServerUrl + "/Sessions/Playing"
            xhr.open("POST", url)
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
            xhr.send(JSON.stringify({
                "ItemId": itemId,
                "PositionTicks": Math.floor((posSeconds || 0) * 10000000),
                "IsPaused": false,
                "EventName": "start"
            }))
        }
    }

    function reportPlaybackProgress(itemId, posSeconds, isPaused, eventName) {
        if (!itemId) return
        if (typeof SessionBridge !== "undefined" && liveServerUrl && accessToken) {
            SessionBridge.reportPlaybackProgress(liveServerUrl, accessToken, itemId, posSeconds || 0, isPaused || false, eventName || "timeupdate")
        } else if (liveServerUrl && accessToken) {
            var xhr = new XMLHttpRequest()
            var url = liveServerUrl + "/Sessions/Playing/Progress"
            xhr.open("POST", url)
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
            xhr.send(JSON.stringify({
                "ItemId": itemId,
                "PositionTicks": Math.floor((posSeconds || 0) * 10000000),
                "IsPaused": isPaused || false,
                "EventName": eventName || "timeupdate"
            }))
        }
    }

    function reportPlaybackStopped(itemId, posSeconds) {
        if (!itemId) return
        if (typeof SessionBridge !== "undefined" && liveServerUrl && accessToken) {
            SessionBridge.reportPlaybackStopped(liveServerUrl, accessToken, itemId, posSeconds || 0)
        } else if (liveServerUrl && accessToken) {
            var xhr = new XMLHttpRequest()
            var url = liveServerUrl + "/Sessions/Playing/Stopped"
            xhr.open("POST", url)
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
            xhr.send(JSON.stringify({
                "ItemId": itemId,
                "PositionTicks": Math.floor((posSeconds || 0) * 10000000),
                "EventName": "stop"
            }))
        }
    }
}
