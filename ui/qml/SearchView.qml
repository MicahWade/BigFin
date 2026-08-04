import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: searchView
    anchors.fill: parent

    signal itemSelected(var item)
    signal requestSidebarFocus()

    property alias defaultFocusItem: searchInput

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 24
        spacing: 24

        // Search Input Bar
        Rectangle {
            id: searchInputBox
            Layout.fillWidth: true
            height: 60
            radius: 12
            color: "#0d1322"
            border.color: searchInput.activeFocus ? AppData.currentTheme.accent : "#1e293b"
            border.width: searchInput.activeFocus ? 3 : 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 16

                Image {
                    width: 22
                    height: 22
                    source: "assets/icons/search.svg"
                    fillMode: Image.PreserveAspectFit
                }

                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "Search Movies, TV Shows, Directors, Genres..."
                    placeholderTextColor: "#64748b"
                    font.pixelSize: 18
                    color: "#ffffff"
                    background: null
                    focus: true

                    onTextChanged: {
                        if (text.length > 1) {
                            AppData.searchJellyfin(text, function(results) {})
                        }
                    }

                    Keys.onDownPressed: function(event) {
                        if (searchResultsGrid.count > 0) {
                            searchResultsGrid.forceActiveFocus()
                            if (searchResultsGrid.currentItem) searchResultsGrid.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }

                    // Enforce top boundary on Up key
                    Keys.onUpPressed: function(event) {
                        event.accepted = true
                    }

                    Keys.onLeftPressed: function(event) {
                        if (cursorPosition === 0) {
                            searchView.requestSidebarFocus()
                            event.accepted = true
                        }
                    }
                }
            }
        }

        // Search Results Section
        Text {
            text: searchInput.text === "" ? "Explore Library" : ("Search Results (" + searchResultsGrid.count + ")")
            font.pixelSize: 22
            font.bold: true
            color: "#ffffff"
        }

        GridView {
            id: searchResultsGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: 210
            cellHeight: 330
            clip: true
            focus: true
            keyNavigationWraps: false

            model: searchInput.text.length > 1 ? AppData.searchResults : AppData.mediaGrid

            Keys.onLeftPressed: function(event) {
                var columns = Math.max(1, Math.floor(searchResultsGrid.width / searchResultsGrid.cellWidth))
                if (currentIndex <= 0 || columns <= 0 || currentIndex % columns === 0) {
                    searchView.requestSidebarFocus()
                } else {
                    currentIndex = currentIndex - 1
                    if (currentItem) currentItem.forceActiveFocus()
                }
                event.accepted = true
            }

            delegate: Item {
                width: searchResultsGrid.cellWidth
                height: searchResultsGrid.cellHeight
                focus: true

                onActiveFocusChanged: {
                    if (activeFocus) {
                        searchCard.forceActiveFocus()
                    }
                }

                Rectangle {
                    id: searchCard
                    width: 195
                    height: 315
                    anchors.centerIn: parent
                    radius: 12
                    color: activeFocus ? AppData.currentTheme.focusCard : "#0d1322"
                    border.color: activeFocus ? AppData.currentTheme.accent : "#1e293b"
                    border.width: activeFocus ? 4 : 1
                    focus: true

                    Behavior on border.color { ColorAnimation { duration: 120 } }

                    onActiveFocusChanged: {
                        if (activeFocus) {
                            searchResultsGrid.currentIndex = index
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
                                width: 44
                                height: 22
                                radius: 4
                                color: "#cc0f172a"

                                Text {
                                    anchors.centerIn: parent
                                    text: "★ " + modelData.rating
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#fbbf24"
                                }
                            }
                        }

                        Text {
                            text: modelData.title
                            font.pixelSize: 14
                            font.bold: true
                            color: searchCard.activeFocus ? "#ffffff" : "#e2e8f0"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: (modelData.mediaType === "Series" || modelData.mediaType === "Episode") ? (modelData.subtitle || modelData.seasonsEpisodesStr || (modelData.year + " • " + modelData.duration)) : (modelData.year + " • " + modelData.duration)
                            font.pixelSize: 11
                            color: searchCard.activeFocus ? "#e2e8f0" : "#94a3b8"
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            searchResultsGrid.currentIndex = index
                            searchCard.forceActiveFocus()
                            searchView.itemSelected(modelData)
                        }
                    }

                    Keys.onReturnPressed: searchView.itemSelected(modelData)
                    Keys.onSpacePressed: searchView.itemSelected(modelData)

                    Keys.onUpPressed: function(event) {
                        var columns = Math.max(1, Math.floor(searchResultsGrid.width / searchResultsGrid.cellWidth))
                        if (index < columns) {
                            searchInput.forceActiveFocus()
                            event.accepted = true
                        }
                    }

                    Keys.onLeftPressed: function(event) {
                        var columns = Math.max(1, Math.floor(searchResultsGrid.width / searchResultsGrid.cellWidth))
                        if (index <= 0 || columns <= 0 || index % columns === 0) {
                            searchView.requestSidebarFocus()
                        } else {
                            searchResultsGrid.currentIndex = index - 1
                            if (searchResultsGrid.currentItem) searchResultsGrid.currentItem.forceActiveFocus()
                        }
                        event.accepted = true
                    }
                }
            }
        }
    }
}
