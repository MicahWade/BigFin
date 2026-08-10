import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: serverModal
    anchors.fill: parent
    color: "#e6080c14"
    z: 200

    signal serverConnected(string serverIp, string serverName, string username, string token)

    // Flow State: 1 = Enter Server IP, 2 = Enter User Credentials
    property int currentStep: 1
    property string rawInputIp: AppData.liveServerUrl ? AppData.liveServerUrl : ""
    property string formattedUrl: ""
    property string discoveredServerName: ""
    property string discoveredVersion: ""

    property string inputUsername: ""
    property string inputPassword: ""
    property string statusMessage: AppData.connectionError ? AppData.connectionError : ""
    property bool isConnecting: false
    property var ipCandidates: []
    property int currentIpIndex: 0

    Rectangle {
        id: dialogCard
        width: Math.min(640, parent.width - 64)
        height: currentStep === 1 ? 440 : 500
        anchors.centerIn: parent
        radius: 16
        color: AppData.currentTheme.cardBg
        border.color: AppData.currentTheme.accent
        border.width: 2

        Behavior on height { NumberAnimation { duration: 180 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 36
            spacing: 20

            // Brand & Setup Title Header
            RowLayout {
                spacing: 16

                Rectangle {
                    width: 52
                    height: 52
                    radius: 12
                    color: "#0f172a"
                    border.color: AppData.currentTheme.accent
                    border.width: 1

                    Image {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        source: "assets/Logo.png"
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }

                ColumnLayout {
                    spacing: 4
                    Text {
                        text: currentStep === 1 ? "Connect to Jellyfin Server" : ("Sign In to " + (discoveredServerName !== "" ? discoveredServerName : "Jellyfin Server"))
                        font.pixelSize: 24
                        font.bold: true
                        color: "#ffffff"
                    }
                    Text {
                        text: currentStep === 1 ? "Enter your Jellyfin Server IP address or host URL to begin" : ("Server: " + formattedUrl + (discoveredVersion !== "" ? " (v" + discoveredVersion + ")" : ""))
                        font.pixelSize: 13
                        color: "#94a3b8"
                    }
                }
            }

            // STEP 1: SERVER IP INPUT
            ColumnLayout {
                visible: currentStep === 1
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "JELLYFIN SERVER IP / HOST ADDRESSES"
                    font.pixelSize: 11
                    font.bold: true
                    color: AppData.currentTheme.accent
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    radius: 10
                    color: "#090d16"
                    border.color: ipInput.activeFocus ? AppData.currentTheme.accent : "#334155"
                    border.width: ipInput.activeFocus ? 3 : 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Image {
                            width: 20
                            height: 20
                            source: "assets/icons/logo.svg"
                            fillMode: Image.PreserveAspectFit
                        }

                        TextField {
                            id: ipInput
                            Layout.fillWidth: true
                            text: serverModal.rawInputIp
                            placeholderText: "e.g. 192.168.1.50, 10.0.0.5 or http://jellyfin.local:8096"
                            placeholderTextColor: "#64748b"
                            font.pixelSize: 16
                            font.bold: true
                            color: "#ffffff"
                            background: null
                            focus: true
                            enabled: !serverModal.isConnecting

                            onTextChanged: serverModal.rawInputIp = text

                            onAccepted: processStep1()
                            Keys.onReturnPressed: processStep1()
                            Keys.onEnterPressed: processStep1()
                            Keys.onSelectPressed: processStep1()

                            Keys.onDownPressed: function(event) {
                                step1NextBtn.forceActiveFocus()
                                event.accepted = true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: ipInput.forceActiveFocus()
                    }
                }

                Text {
                    text: "💡 Supports multiple IP addresses separated by commas (e.g. 192.168.1.50, 10.0.0.5)"
                    font.pixelSize: 12
                    color: "#64748b"
                    Layout.fillWidth: true
                }
            }

            // STEP 2: USER CREDENTIALS INPUT
            ColumnLayout {
                visible: currentStep === 2
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "JELLYFIN ACCOUNT USERNAME"
                    font.pixelSize: 11
                    font.bold: true
                    color: AppData.currentTheme.accent
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 10
                    color: "#090d16"
                    border.color: userInput.activeFocus ? AppData.currentTheme.accent : "#334155"
                    border.width: userInput.activeFocus ? 2 : 1

                    TextField {
                        id: userInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        text: serverModal.inputUsername
                        placeholderText: "Username"
                        placeholderTextColor: "#64748b"
                        font.pixelSize: 15
                        color: "#ffffff"
                        background: null
                        enabled: !serverModal.isConnecting

                        onTextChanged: serverModal.inputUsername = text

                        Keys.onDownPressed: function(event) {
                            passInput.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: userInput.forceActiveFocus()
                    }
                }

                Text {
                    text: "PASSWORD"
                    font.pixelSize: 11
                    font.bold: true
                    color: AppData.currentTheme.accent
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 50
                    radius: 10
                    color: "#090d16"
                    border.color: passInput.activeFocus ? AppData.currentTheme.accent : "#334155"
                    border.width: passInput.activeFocus ? 2 : 1

                    TextField {
                        id: passInput
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        echoMode: TextInput.Password
                        text: serverModal.inputPassword
                        placeholderText: "Password"
                        placeholderTextColor: "#64748b"
                        font.pixelSize: 15
                        color: "#ffffff"
                        background: null
                        enabled: !serverModal.isConnecting

                        onTextChanged: serverModal.inputPassword = text

                        onAccepted: processStep2()
                        Keys.onReturnPressed: processStep2()
                        Keys.onEnterPressed: processStep2()
                        Keys.onSelectPressed: processStep2()

                        Keys.onUpPressed: function(event) {
                            userInput.forceActiveFocus()
                            event.accepted = true
                        }
                        Keys.onDownPressed: function(event) {
                            step2ConnectBtn.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.IBeamCursor
                        onClicked: passInput.forceActiveFocus()
                    }
                }
            }

            // Status / Connection Feedback Message
            Text {
                text: serverModal.statusMessage
                font.pixelSize: 13
                font.bold: true
                color: serverModal.statusMessage.indexOf("Connected") >= 0 || serverModal.statusMessage.indexOf("Discovered") >= 0 ? "#22c55e" : (serverModal.statusMessage.indexOf("Failed") >= 0 || serverModal.statusMessage.indexOf("Unable") >= 0 || serverModal.statusMessage.indexOf("Could not") >= 0 || serverModal.statusMessage.indexOf("Error") >= 0 ? "#ef4444" : "#38bdf8")
                visible: serverModal.statusMessage !== ""
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillHeight: true }

            // STEP 1 ACTION BUTTON: CONNECT SERVER IP
            Rectangle {
                id: step1NextBtn
                visible: currentStep === 1
                Layout.fillWidth: true
                height: 54
                radius: 10
                focus: true
                color: (step1MouseArea.containsMouse || activeFocus) ? AppData.currentTheme.accent : "#0284c7"
                border.color: (step1MouseArea.containsMouse || activeFocus) ? "#ffffff" : AppData.currentTheme.accent
                border.width: (step1MouseArea.containsMouse || activeFocus) ? 3 : 1

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Image {
                        width: 20
                        height: 20
                        source: "assets/icons/play.svg"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        text: isConnecting ? "Testing Connection..." : "Connect Server"
                        font.pixelSize: 17
                        font.bold: true
                        color: (step1MouseArea.containsMouse || step1NextBtn.activeFocus) ? "#0f172a" : "#ffffff"
                    }
                }

                MouseArea {
                    id: step1MouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        step1NextBtn.forceActiveFocus()
                        processStep1()
                    }
                }
                Keys.onReturnPressed: processStep1()
                Keys.onEnterPressed: processStep1()
                Keys.onSelectPressed: processStep1()
                Keys.onSpacePressed: processStep1()
                Keys.onUpPressed: function(event) {
                    ipInput.forceActiveFocus()
                    event.accepted = true
                }
            }

            // STEP 2 ACTION BUTTON: SIGN IN & LOAD LIVE DATA
            RowLayout {
                visible: currentStep === 2
                Layout.fillWidth: true
                spacing: 16

                Rectangle {
                    height: 54
                    Layout.preferredWidth: 120
                    radius: 10
                    focus: true
                    color: (backMouseArea.containsMouse || activeFocus) ? AppData.currentTheme.accent : "#1e293b"
                    border.color: "#475569"

                    Text {
                        anchors.centerIn: parent
                        text: "Back"
                        font.pixelSize: 15
                        font.bold: true
                        color: "#ffffff"
                    }

                    MouseArea {
                        id: backMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: serverModal.currentStep = 1
                    }
                    Keys.onReturnPressed: serverModal.currentStep = 1
                    Keys.onEnterPressed: serverModal.currentStep = 1
                    Keys.onSelectPressed: serverModal.currentStep = 1
                    Keys.onUpPressed: function(event) {
                        passInput.forceActiveFocus()
                        event.accepted = true
                    }
                    Keys.onRightPressed: function(event) {
                        step2ConnectBtn.forceActiveFocus()
                        event.accepted = true
                    }
                }

                Rectangle {
                    id: step2ConnectBtn
                    Layout.fillWidth: true
                    height: 54
                    radius: 10
                    focus: true
                    color: (step2MouseArea.containsMouse || activeFocus) ? AppData.currentTheme.accent : "#0284c7"
                    border.color: (step2MouseArea.containsMouse || activeFocus) ? "#ffffff" : AppData.currentTheme.accent
                    border.width: (step2MouseArea.containsMouse || activeFocus) ? 3 : 1

                    Text {
                        anchors.centerIn: parent
                        text: isConnecting ? "Authenticating..." : "Sign In & Load Live Media"
                        font.pixelSize: 17
                        font.bold: true
                        color: (step2MouseArea.containsMouse || step2ConnectBtn.activeFocus) ? "#0f172a" : "#ffffff"
                    }

                    MouseArea {
                        id: step2MouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            step2ConnectBtn.forceActiveFocus()
                            processStep2()
                        }
                    }
                    Keys.onReturnPressed: processStep2()
                    Keys.onEnterPressed: processStep2()
                    Keys.onSelectPressed: processStep2()
                    Keys.onSpacePressed: processStep2()
                    Keys.onUpPressed: function(event) {
                        passInput.forceActiveFocus()
                        event.accepted = true
                    }
                    Keys.onLeftPressed: function(event) {
                        backBtn.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }
        }
    }

    function sanitizeUrl(input) {
        var str = input.trim()
        if (str === "") return "http://localhost:8096"
        if (!str.startsWith("http://") && !str.startsWith("https://")) {
            str = "http://" + str
        }
        var protoIndex = str.indexOf("://") + 3
        var afterProtocol = str.substring(protoIndex)
        if (afterProtocol.indexOf(":") === -1 && afterProtocol.indexOf("/") === -1) {
            str = str + ":8096"
        }
        while (str.endsWith("/")) {
            str = str.substring(0, str.length - 1)
        }
        return str
    }

    function parseIpList(input) {
        if (!input || input.trim() === "") return ["http://localhost:8096"]
        var parts = input.split(/[,;\n\r]+/)
        var result = []
        for (var i = 0; i < parts.length; i++) {
            var token = parts[i].trim()
            if (token !== "") {
                var subTokens = token.split(/\s+/)
                for (var j = 0; j < subTokens.length; j++) {
                    var sub = subTokens[j].trim()
                    if (sub !== "") {
                        result.push(sanitizeUrl(sub))
                    }
                }
            }
        }
        return result.length > 0 ? result : ["http://localhost:8096"]
    }

    function processStep1() {
        if (isConnecting) return
        ipCandidates = parseIpList(rawInputIp)
        currentIpIndex = 0
        isConnecting = true
        tryConnectCandidate(0)
    }

    function tryConnectCandidate(index) {
        if (index >= ipCandidates.length) {
            isConnecting = false
            statusMessage = "Could not reach Jellyfin Server at any of the specified IP addresses (" + ipCandidates.join(", ") + "). Check IP address and network connection."
            return
        }

        currentIpIndex = index
        var candidateUrl = ipCandidates[index]
        formattedUrl = candidateUrl
        statusMessage = "Testing connection to " + candidateUrl + (ipCandidates.length > 1 ? " (" + (index + 1) + " of " + ipCandidates.length + " IPs)..." : "...")
        console.log("[JELLYFIN CONNECT] Testing candidate IP " + (index + 1) + "/" + ipCandidates.length + ": GET " + candidateUrl + "/System/Info/Public...")

        var xhr = new XMLHttpRequest()
        xhr.open("GET", candidateUrl + "/System/Info/Public")
        xhr.timeout = 4000

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        discoveredServerName = res.ServerName || "Jellyfin Server"
                        discoveredVersion = res.Version || ""
                        isConnecting = false
                        console.log("[JELLYFIN CONNECT SUCCESS] Connected to server: " + discoveredServerName + " (v" + discoveredVersion + ") at " + candidateUrl)
                        statusMessage = "Connected to " + discoveredServerName + "! Enter account credentials."
                        currentStep = 2
                        Qt.callLater(function() { userInput.forceActiveFocus() })
                    } catch (e) {
                        console.log("[JELLYFIN CONNECT ERROR] Invalid JSON from candidate " + candidateUrl + ": " + e)
                        tryConnectCandidate(index + 1)
                    }
                } else {
                    console.log("[JELLYFIN CONNECT ERROR] Candidate " + candidateUrl + " returned status " + xhr.status)
                    tryConnectCandidate(index + 1)
                }
            }
        }

        xhr.ontimeout = function() {
            console.log("[JELLYFIN CONNECT ERROR] Candidate " + candidateUrl + " timed out!")
            tryConnectCandidate(index + 1)
        }

        xhr.onerror = function() {
            console.log("[JELLYFIN CONNECT ERROR] Network error connecting to candidate " + candidateUrl)
            tryConnectCandidate(index + 1)
        }

        xhr.send()
    }

    function processStep2() {
        if (isConnecting) return
        isConnecting = true
        statusMessage = "Authenticating with " + (discoveredServerName !== "" ? discoveredServerName : "Jellyfin Server") + "..."
        console.log("[JELLYFIN AUTH] Authenticating username: '" + inputUsername + "' on " + formattedUrl + "...")

        var xhr = new XMLHttpRequest()
        xhr.open("POST", formattedUrl + "/Users/AuthenticateByName")
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.setRequestHeader("X-Emby-Authorization", 'MediaBrowser Client="Bigfin", Device="Plasma Bigscreen TV", DeviceId="bigfin-plasma-tv-01", Version="1.0.0"')
        xhr.timeout = 8000

        var payload = JSON.stringify({
            Username: inputUsername,
            Pw: inputPassword
        })

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                isConnecting = false
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var token = res.AccessToken
                        var uId = res.User ? res.User.Id : ""
                        var uName = res.User ? res.User.Name : inputUsername

                        if (!token || !uId) {
                            console.log("[JELLYFIN AUTH ERROR] Missing AccessToken or User ID in response!")
                            statusMessage = "Authentication Failed: Server did not return a valid Access Token."
                            return
                        }

                        console.log("[JELLYFIN AUTH SUCCESS] Granted AccessToken for User: " + uName + " (ID: " + uId + ")")
                        statusMessage = "Authentication Successful! Loading live media items..."

                        AppData.saveNewSession(formattedUrl, discoveredServerName, discoveredVersion, uId, uName, token, rawInputIp)
                        serverConnected(formattedUrl, discoveredServerName, uName, token)
                    } catch (e) {
                        console.log("[JELLYFIN AUTH ERROR] Failed to parse auth response: " + e)
                        statusMessage = "Authentication Failed: Server returned invalid JSON response."
                    }
                } else if (xhr.status === 401) {
                    console.log("[JELLYFIN AUTH FAILED] HTTP 401: Invalid credentials!")
                    statusMessage = "Authentication Failed: Invalid username or password."
                } else {
                    console.log("[JELLYFIN AUTH ERROR] HTTP status: " + xhr.status)
                    statusMessage = "Authentication Error (HTTP " + xhr.status + "). Check username & password."
                }
            }
        }

        xhr.ontimeout = function() {
            isConnecting = false
            console.log("[JELLYFIN AUTH ERROR] Authentication request timed out!")
            statusMessage = "Authentication Timed Out. Check Jellyfin server status."
        }

        xhr.onerror = function() {
            isConnecting = false
            console.log("[JELLYFIN AUTH ERROR] Network error during authentication!")
            statusMessage = "Network error while authenticating. Check server URL."
        }

        xhr.send(payload)
    }
}

