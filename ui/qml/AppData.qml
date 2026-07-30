pragma Singleton
import QtQuick 2.15
import QtQml 2.15

Item {
    id: appData

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
    property var musicList: []
    property var playlistsList: []
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
            { id: "tvshows", title: "TV Series", icon: "assets/icons/tv.svg" },
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

    function loadSavedSessions() {
        if (typeof SessionBridge !== "undefined") {
            try {
                var jsonStr = SessionBridge.loadSessionsJson()
                var data = JSON.parse(jsonStr)
                savedSessions = data.sessions || []
                activeSessionId = data.activeSessionId || ""
                console.log("[SESSIONS] Loaded " + savedSessions.length + " sessions. Active ID: " + activeSessionId)

                if (activeSessionId !== "" && savedSessions.length > 0) {
                    for (var i = 0; i < savedSessions.length; i++) {
                        var s = savedSessions[i]
                        if (s.id === activeSessionId) {
                            console.log("[SESSIONS] Auto-logging into saved session for " + s.username + " at " + s.serverUrl)
                            serverName = s.serverName
                            serverVersion = s.serverVersion
                            authenticatedUser = s.username
                            loadLiveServerItems(s.serverUrl, s.userId, s.accessToken)
                            return
                        }
                    }
                }
            } catch (e) {
                console.log("[SESSIONS WARN] Failed to parse sessions JSON: " + e)
            }
        }
        setConnectionFailed("No active Jellyfin server session. Please connect to your server.")
    }

    function saveNewSession(sUrl, sName, sVersion, uId, uName, token) {
        liveServerUrl = sUrl
        serverName = sName
        serverVersion = sVersion
        authenticatedUser = uName
        userId = uId
        accessToken = token

        if (typeof SessionBridge !== "undefined") {
            SessionBridge.saveSession(sUrl, sName, sVersion, uId, uName, token)
        }
        loadLiveServerItems(sUrl, uId, token)
    }

    function switchToSession(sessId) {
        if (typeof SessionBridge !== "undefined") {
            var success = SessionBridge.switchSession(sessId)
            if (success) {
                loadSavedSessions()
            }
        } else {
            for (var i = 0; i < savedSessions.length; i++) {
                if (savedSessions[i].id === sessId) {
                    var s = savedSessions[i]
                    activeSessionId = sessId
                    serverName = s.serverName
                    authenticatedUser = s.username
                    loadLiveServerItems(s.serverUrl, s.userId, s.accessToken)
                    break
                }
            }
        }
    }

    function deleteSession(sessId) {
        if (typeof SessionBridge !== "undefined") {
            SessionBridge.deleteSession(sessId)
            loadSavedSessions()
        } else {
            var filtered = []
            for (var i = 0; i < savedSessions.length; i++) {
                if (savedSessions[i].id !== sessId) filtered.push(savedSessions[i])
            }
            savedSessions = filtered
            if (activeSessionId === sessId) {
                activeSessionId = filtered.length > 0 ? filtered[0].id : ""
                if (activeSessionId === "") {
                    setConnectionFailed("Session deleted. Please connect to a Jellyfin server.")
                }
            }
        }
    }

    function logoutCurrentSession() {
        if (typeof SessionBridge !== "undefined") {
            SessionBridge.logoutActiveSession()
        }
        activeSessionId = ""
        setConnectionFailed("Logged out. Please sign in to your Jellyfin server.")
    }

    // Master function to trigger all specific category fetches after verifying server connection
    function loadLiveServerItems(baseUrl, uId, token) {
        liveServerUrl = baseUrl
        userId = uId
        accessToken = token
        connectionError = ""

        console.log("[JELLYFIN API] Verifying server connection & loading items for User ID: " + uId + " at " + baseUrl)

        var verifyXhr = new XMLHttpRequest()
        verifyXhr.open("GET", baseUrl + "/System/Info/Public")
        verifyXhr.timeout = 5000

        verifyXhr.onreadystatechange = function() {
            if (verifyXhr.readyState === XMLHttpRequest.DONE) {
                if (verifyXhr.status === 200) {
                    try {
                        var res = JSON.parse(verifyXhr.responseText)
                        serverName = res.ServerName || serverName || "Jellyfin Server"
                        serverVersion = res.Version || serverVersion || ""
                    } catch (e) {}

                    console.log("[JELLYFIN API] Server verified at " + baseUrl)
                    isConnectedToLiveServer = true
                    isAuthenticated = true
                    connectionError = ""
                    connectionStatusChanged()

                    fetchMovies()
                    fetchTVShows()
                    fetchMusic()
                    fetchFavorites()
                    fetchContinueWatching()
                    fetchNextUpList()
                    fetchRecentlyAdded()
                } else {
                    var errStr = "Unable to connect to Jellyfin server at " + baseUrl + " (HTTP " + verifyXhr.status + "). Check server URL & state."
                    console.log("[JELLYFIN API ERROR] " + errStr)
                    setConnectionFailed(errStr)
                }
            }
        }

        verifyXhr.ontimeout = function() {
            var errStr = "Connection to Jellyfin server at " + baseUrl + " timed out. Ensure the server is online."
            console.log("[JELLYFIN API ERROR] " + errStr)
            setConnectionFailed(errStr)
        }

        verifyXhr.onerror = function() {
            var errStr = "Network error: Could not reach Jellyfin server at " + baseUrl + ". Check IP address & port."
            console.log("[JELLYFIN API ERROR] " + errStr)
            setConnectionFailed(errStr)
        }

        verifyXhr.send()
    }

    function parseJellyfinItems(items) {
        var result = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            
            var isEpisode = (item.Type === "Episode")
            var isPlaylist = (item.Type === "Playlist")
            var isMusic = (item.Type === "MusicAlbum" || item.Type === "Audio" || item.Type === "MusicArtist" || item.Type === "Playlist")
            var displayTitle = isEpisode ? (item.SeriesName || item.Name || "Untitled") : (item.Name || "Untitled")
            
            var sNum = item.ParentIndexNumber !== undefined ? item.ParentIndexNumber : ""
            var eNum = item.IndexNumber !== undefined ? item.IndexNumber : ""
            var epCode = (sNum !== "" ? ("S" + sNum) : "") + (eNum !== "" ? (":E" + eNum) : "")
            
            var displaySubtitle = ""
            if (isEpisode) {
                displaySubtitle = epCode !== "" ? (epCode + (item.Name ? (" - " + item.Name) : "")) : (item.Name || "")
            } else if (isPlaylist) {
                displaySubtitle = item.ChildCount ? (item.ChildCount + " Tracks • Playlist") : "Playlist"
            } else if (isMusic) {
                if (item.AlbumArtist) {
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

            // High Quality Image Hierarchy
            var poster = liveServerUrl + "/Items/" + item.Id + "/Images/Primary?maxWidth=800&quality=90&format=JPG"
            if (isEpisode && item.SeasonId) {
                poster = liveServerUrl + "/Items/" + item.SeasonId + "/Images/Primary?maxWidth=800&quality=90&format=JPG"
            }

            var backdrop = poster
            if (item.BackdropImageTags && item.BackdropImageTags.length > 0) {
                backdrop = liveServerUrl + "/Items/" + item.Id + "/Images/Backdrop?maxWidth=1200&quality=90&format=JPG"
            } else if (item.ParentBackdropImageTags && item.ParentBackdropImageTags.length > 0 && item.ParentBackdropItemId) {
                backdrop = liveServerUrl + "/Items/" + item.ParentBackdropItemId + "/Images/Backdrop?maxWidth=1200&quality=90&format=JPG"
            } else if (item.SeriesId) {
                backdrop = liveServerUrl + "/Items/" + item.SeriesId + "/Images/Backdrop?maxWidth=1200&quality=90&format=JPG"
            }

            if (typeof SessionBridge !== "undefined" && SessionBridge.getCachedImage) {
                poster = SessionBridge.getCachedImage(poster)
                backdrop = SessionBridge.getCachedImage(backdrop)
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
                        pImg = liveServerUrl + "/Items/" + person.Id + "/Images/Primary?maxWidth=300&quality=85"
                    } else if (person.Name) {
                        pImg = liveServerUrl + "/Persons/" + encodeURIComponent(person.Name) + "/Images/Primary?maxWidth=300&quality=85"
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
                episodeName: item.Name || "",
                seriesName: item.SeriesName || "",
                seriesId: item.SeriesId || "",
                seasonId: item.SeasonId || "",
                seasonNumber: sNum,
                episodeNumber: eNum,
                mediaType: item.Type || "Movie",
                year: item.ProductionYear ? String(item.ProductionYear) : "2024",
                rating: item.CommunityRating ? item.CommunityRating.toFixed(1) : "8.5",
                duration: item.RunTimeTicks ? Math.round(item.RunTimeTicks / 600000000) + "m" : "22m",
                overview: item.Overview || "Jellyfin media stream",
                posterUrl: poster,
                backdropUrl: backdrop,
                genres: item.Genres || ["Animation", "Action", "Adventure"],
                isFavorite: item.UserData ? item.UserData.IsFavorite : false,
                isPlayed: item.UserData ? item.UserData.Played : false,
                progress: (item.UserData && item.UserData.PlayedPercentage) ? (item.UserData.PlayedPercentage / 100) : 0,
                officialRating: officialRating,
                studio: studioStr,
                tags: tagsStr,
                externalUrls: externalUrls,
                people: peopleList,
                videoSpec: videoSpec,
                audioSpec: audioSpec,
                subtitlesSpec: subtitlesSpec,
                premiereDate: item.PremiereDate ? item.PremiereDate.substring(0, 10) : "",
                childCount: item.ChildCount !== undefined ? item.ChildCount : 0,
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
            returnDefaultSeasons()
            return
        }
        console.log("[JELLYFIN API] Fetching Seasons for Series ID: " + seriesId)
        
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + seriesId + "&IncludeItemTypes=Season&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var seasons = parseJellyfinItems(res.Items || [])
                        console.log("[JELLYFIN API] Seasons returned via ParentId: " + seasons.length)
                        if (seasons.length > 0) {
                            if (callback) callback(seasons)
                            return
                        }
                    } catch (e) {}
                }
                
                var xhr2 = new XMLHttpRequest()
                var url2 = liveServerUrl + "/Shows/" + seriesId + "/Seasons?UserId=" + userId + "&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
                xhr2.open("GET", url2)
                xhr2.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                xhr2.onreadystatechange = function() {
                    if (xhr2.readyState === XMLHttpRequest.DONE) {
                        if (xhr2.status === 200) {
                            try {
                                var res2 = JSON.parse(xhr2.responseText)
                                var seasons2 = parseJellyfinItems(res2.Items || [])
                                console.log("[JELLYFIN API] Seasons returned via /Shows: " + seasons2.length)
                                if (seasons2.length > 0) {
                                    if (callback) callback(seasons2)
                                    return
                                }
                            } catch (e) {}
                        }
                        
                        var xhr3 = new XMLHttpRequest()
                        var url3 = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + seriesId + "&Fields=PrimaryImageAspectRatio,Overview,UserData,ChildCount"
                        xhr3.open("GET", url3)
                        xhr3.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                        xhr3.onreadystatechange = function() {
                            if (xhr3.readyState === XMLHttpRequest.DONE) {
                                if (xhr3.status === 200) {
                                    try {
                                        var res3 = JSON.parse(xhr3.responseText)
                                        var seasons3 = parseJellyfinItems(res3.Items || [])
                                        if (seasons3.length > 0) {
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
            returnDefaultEpisodes()
            return
        }
        console.log("[JELLYFIN API] Fetching episodes for Series ID: " + seriesId + " | Season ID: " + seasonId)

        var targetParent = seasonId ? seasonId : seriesId
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + targetParent + "&IncludeItemTypes=Episode" + (seasonId ? "" : "&Recursive=true") + "&Fields=PrimaryImageAspectRatio,Overview,MediaSources,UserData,SeriesName,SeriesId,SeasonId,People,Studios,Tags,OfficialRating,ExternalUrls,ProviderIds,PremiereDate"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var episodes = parseJellyfinItems(res.Items || [])
                        console.log("[JELLYFIN API] Episodes returned via ParentId: " + episodes.length)
                        if (episodes.length > 0) {
                            if (callback) callback(episodes)
                            return
                        }
                    } catch (e) {}
                }

                var xhr2 = new XMLHttpRequest()
                var url2 = liveServerUrl + "/Shows/" + seriesId + "/Episodes?UserId=" + userId + (seasonId ? ("&SeasonId=" + seasonId) : "") + "&Fields=PrimaryImageAspectRatio,Overview,MediaSources,UserData,People,Studios,Tags,OfficialRating,ExternalUrls,ProviderIds,PremiereDate"
                xhr2.open("GET", url2)
                xhr2.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                xhr2.onreadystatechange = function() {
                    if (xhr2.readyState === XMLHttpRequest.DONE) {
                        if (xhr2.status === 200) {
                            try {
                                var res2 = JSON.parse(xhr2.responseText)
                                var episodes2 = parseJellyfinItems(res2.Items || [])
                                console.log("[JELLYFIN API] Episodes returned via /Shows: " + episodes2.length)
                                if (episodes2.length > 0) {
                                    if (callback) callback(episodes2)
                                    return
                                }
                            } catch (e) {}
                        }
                        
                        var xhr3 = new XMLHttpRequest()
                        var url3 = liveServerUrl + "/Users/" + userId + "/Items?ParentId=" + targetParent + "&Fields=PrimaryImageAspectRatio,Overview,MediaSources,UserData,SeriesName,SeriesId,SeasonId,People,Studios,Tags,OfficialRating,ExternalUrls,ProviderIds,PremiereDate"
                        xhr3.open("GET", url3)
                        xhr3.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
                        xhr3.onreadystatechange = function() {
                            if (xhr3.readyState === XMLHttpRequest.DONE) {
                                if (xhr3.status === 200) {
                                    try {
                                        var res3 = JSON.parse(xhr3.responseText)
                                        var episodes3 = parseJellyfinItems(res3.Items || [])
                                        if (episodes3.length > 0) {
                                            if (callback) callback(episodes3)
                                            return
                                        }
                                    } catch (e) {}
                                }
                                returnDefaultEpisodes()
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

    function fetchNextUpForSeries(seriesId, callback) {
        function returnDefaultNextUp() {
            if (callback) callback(null)
        }

        if (!liveServerUrl || !userId) {
            returnDefaultNextUp()
            return
        }
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Shows/NextUp?UserId=" + userId + "&SeriesId=" + seriesId + "&Fields=PrimaryImageAspectRatio,Overview,MediaSources,UserData"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var items = parseJellyfinItems(res.Items || [])
                    if (items.length > 0) {
                        if (callback) callback(items[0])
                        return
                    }
                } catch (e) {}
            }
            if (xhr.readyState === XMLHttpRequest.DONE) {
                returnDefaultNextUp()
            }
        }
        xhr.send()
    }

    function fetchMovies() {
        if (!liveServerUrl || !userId) return
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
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Series&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData&Limit=100"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var parsed = parseJellyfinItems(res.Items || [])
                    tvShowsList = parsed
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
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items/Resume?Limit=30&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,SeriesId,SeriesName"
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
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Shows/NextUp?UserId=" + userId + "&Limit=25&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,SeriesId,SeriesName"
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
                    console.log("[JELLYFIN API] Loaded " + parsed.length + " NEXT UP episodes")
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Next Up parse fail: " + e)
                }
            }
        }
        xhr.send()
    }

    function fetchMusic() {
        if (!liveServerUrl || !userId) return
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?IncludeItemTypes=Playlist,MusicAlbum,Audio&Recursive=true&SortBy=SortName&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist,ChildCount&Limit=100"
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
                    playlistsList = playlists
                    musicList = playlists.concat(nonPlaylists)
                    console.log("[JELLYFIN API] Loaded " + playlists.length + " Playlists and " + nonPlaylists.length + " Music items")
                    updateMasterGrid()
                } catch (e) {
                    console.log("[JELLYFIN API ERROR] Music parse fail: " + e)
                }
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
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items/Latest?IncludeItemTypes=" + itemType + "&Limit=16&Fields=PrimaryImageAspectRatio,Overview,Genres,CommunityRating,RunTimeTicks,ProductionYear,UserData,Artists,ArtistItems,AlbumArtist"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var rawItems = Array.isArray(res) ? res : (res.Items || [])
                    var parsed = parseJellyfinItems(rawItems)
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

    function searchJellyfin(query, callback) {
        if (!liveServerUrl || !userId) return
        var xhr = new XMLHttpRequest()
        var url = liveServerUrl + "/Users/" + userId + "/Items?SearchTerm=" + encodeURIComponent(query) + "&IncludeItemTypes=Movie,Series,Episode,Audio&Fields=PrimaryImageAspectRatio,Overview,CommunityRating,RunTimeTicks,ProductionYear&Limit=40"
        xhr.open("GET", url)
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="TV", DeviceId="bigfin-01", Version="1.0.0", Token="' + accessToken + '"')

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    var results = parseJellyfinItems(res.Items || [])
                    searchResults = results
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
                if (xhr.status === 200) fetchFavorites()
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
