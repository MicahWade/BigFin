import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: gridView
    anchors.fill: parent

    signal itemSelected(var item)
    signal requestSidebarFocus()

    property string categoryFilter: "movies"
    property alias defaultFocusItem: mediaGridView

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
                text: categoryFilter === "movies" ? "Movies Library" : (categoryFilter === "tvshows" ? "TV Series Library" : (categoryFilter === "music" ? "Music Library • Playlists & Albums" : "Favorites"))
                font.pixelSize: 28
                font.bold: true
                color: "#ffffff"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: mediaGridView.count + " Titles"
                font.pixelSize: 14
                color: "#94a3b8"
            }
        }

        // Clean Flat Media Grid
        GridView {
            id: mediaGridView
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 210
            cellHeight: 330
            clip: true
            focus: true
            model: {
                if (categoryFilter === "movies") {
                    return AppData.moviesList.length > 0 ? AppData.moviesList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Movie" || i.mediaType === "movie" })
                } else if (categoryFilter === "tvshows") {
                    return AppData.tvShowsList.length > 0 ? AppData.tvShowsList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Series" || i.mediaType === "series" || i.mediaType === "TvProgram" })
                } else if (categoryFilter === "music") {
                    var rawMusic = AppData.musicList.length > 0 ? AppData.musicList : AppData.mediaGrid.filter(function(i){ return i.mediaType === "Playlist" || i.mediaType === "MusicAlbum" || i.mediaType === "Audio" || i.mediaType === "MusicArtist" })
                    var plList = []
                    var otherList = []
                    for (var m = 0; m < rawMusic.length; m++) {
                        if (rawMusic[m].mediaType === "Playlist" || rawMusic[m].Type === "Playlist") {
                            plList.push(rawMusic[m])
                        } else {
                            otherList.push(rawMusic[m])
                        }
                    }
                    return plList.concat(otherList)
                } else if (categoryFilter === "favorites") {
                    return AppData.favoritesList.length > 0 ? AppData.favoritesList : AppData.mediaGrid.filter(function(i){ return i.isFavorite })
                }
                return AppData.mediaGrid
            }

            delegate: Item {
                width: mediaGridView.cellWidth
                height: mediaGridView.cellHeight
                focus: true

                onActiveFocusChanged: {
                    if (activeFocus) {
                        gridCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: gridCard
                    width: 195
                    height: 315
                    anchors.centerIn: parent
                    radius: 12
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    focus: true

                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            mediaGridView.currentIndex = index
                        }
                    }

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
                                source: modelData.posterUrl
                                fillMode: Image.PreserveAspectCrop
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                width: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? 72 : 44
                                height: 22
                                radius: 4
                                color: (modelData.mediaType === "Playlist" || modelData.Type === "Playlist") ? "#cc6366f1" : "#cc0f172a"

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
                            text: modelData.title
                            font.pixelSize: 14
                            font.bold: true
                            color: gridCard.activeFocus ? "#ffffff" : "#e2e8f0"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (modelData.mediaType === "Series" || modelData.mediaType === "series" || modelData.mediaType === "TvProgram") ? (modelData.seasonsEpisodesStr || modelData.subtitle || (modelData.year + " • " + modelData.duration)) : (modelData.year + " • " + modelData.duration)
                            font.pixelSize: 11
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
                        if (index % columns === 0) {
                            gridView.requestSidebarFocus()
                            event.accepted = true
                        }
                    }

                    Keys.onUpPressed: function(event) {
                        var columns = Math.max(1, Math.floor(mediaGridView.width / mediaGridView.cellWidth))
                        if (index < columns) {
                            event.accepted = true
                        }
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
