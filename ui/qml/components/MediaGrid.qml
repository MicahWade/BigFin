import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami

Kirigami.ScrollablePage {
    id: mediaGridPage
    title: "Media Library"

    signal itemSelected(var item)

    // Component completion focus initialization
    Component.onCompleted: {
        categoryList.forceActiveFocus()
    }

    // Categorized Data Models
    ListModel {
        id: musicModel
        ListElement {
            itemId: "pl1"
            title: "Favorite Rock & Classics"
            mediaType: "Playlist"
            year: "2024"
            rating: "9.5"
            overview: "Top rated classic rock and pop tracks playlist."
            posterUrl: "../assets/posters/american_pie.svg"
        }
        ListElement {
            itemId: "1"
            title: "American Pie"
            mediaType: "MusicAlbum"
            year: "1971"
            rating: "9.2"
            overview: "Classic Don McLean American Pie album."
            posterUrl: "../assets/posters/american_pie.svg"
        }
        ListElement {
            itemId: "2"
            title: "Stories From The Western Front"
            mediaType: "MusicAlbum"
            year: "2023"
            rating: "8.9"
            overview: "Heavy metal concept album by Sabaton."
            posterUrl: "../assets/posters/sabaton.svg"
        }
    }

    ListModel {
        id: blockbusterMoviesModel
        ListElement {
            itemId: "6"
            title: "Dune: Part Two"
            mediaType: "Movie"
            year: "2024"
            rating: "8.5"
            overview: "Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family."
            posterUrl: "../assets/posters/dune2.svg"
        }
        ListElement {
            itemId: "7"
            title: "Interstellar"
            mediaType: "Movie"
            year: "2014"
            rating: "8.7"
            overview: "A team of researchers travels through a wormhole in space in an attempt to ensure humanity's survival."
            posterUrl: "../assets/posters/interstellar.svg"
        }
        ListElement {
            itemId: "8"
            title: "Blade Runner 2049"
            mediaType: "Movie"
            year: "2017"
            rating: "8.0"
            overview: "Young Blade Runner K's discovery of a long-buried secret leads him to track down former Blade Runner Rick Deckard."
            posterUrl: "../assets/posters/bladerunner.svg"
        }
    }

    ListModel {
        id: topRatedClassicsModel
        ListElement {
            itemId: "9"
            title: "Breaking Bad"
            mediaType: "Series"
            year: "2008"
            rating: "9.5"
            overview: "A chemistry teacher diagnosed with lung cancer turns to manufacturing methamphetamine with a former student."
            posterUrl: "../assets/posters/breakingbad.svg"
        }
        ListElement {
            itemId: "10"
            title: "The Mandalorian"
            mediaType: "Series"
            year: "2019"
            rating: "8.6"
            overview: "The travels of a lone bounty hunter in the outer reaches of the galaxy."
            posterUrl: "../assets/posters/mandalorian.svg"
        }
    }

    // Categories Container Model
    ListModel {
        id: categoriesModel
        ListElement { categoryName: "🎵 Recent Music Albums"; mediaModelId: "music" }
        ListElement { categoryName: "🎬 Blockbuster Movies"; mediaModelId: "movies" }
        ListElement { categoryName: "⭐ Top Rated Classics"; mediaModelId: "classics" }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        // Top Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 24
            Layout.rightMargin: 24

            Text {
                text: "Home Library"
                font.pixelSize: 32
                font.bold: true
                color: "#ffffff"
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Use ARROW KEYS / D-PAD to Navigate • ENTER to Select"
                font.pixelSize: 14
                font.bold: true
                color: "#00a4dc"
            }
        }

        // Categorized Vertical Row List
        ListView {
            id: categoryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            focus: true
            clip: true
            model: categoriesModel

            // High-Speed Snappy TV Vertical Scrolling
            highlightMoveDuration: 75
            highlightResizeDuration: 75
            maximumFlickVelocity: 6000
            flickDeceleration: 8000
            boundsBehavior: Flickable.StopAtBounds
            highlightRangeMode: ListView.ApplyRange

            delegate: ColumnLayout {
                id: categoryRow
                width: categoryList.width
                spacing: 12

                property int rowIndex: index
                property string categoryKey: mediaModelId

                // Category Title Header
                Text {
                    text: model.categoryName
                    font.pixelSize: 22
                    font.bold: true
                    color: "#e0e4f0"
                    Layout.leftMargin: 24
                }

                // Horizontal Carousel Row
                ListView {
                    id: horizontalRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 330
                    orientation: ListView.Horizontal
                    spacing: 20
                    clip: true
                    focus: categoryList.currentIndex === index

                    model: categoryRow.categoryKey === "music" ? musicModel :
                           (categoryRow.categoryKey === "movies" ? blockbusterMoviesModel : topRatedClassicsModel)

                    delegate: Item {
                        id: posterCard
                        width: 200
                        height: 310

                        property bool isItemFocused: horizontalRow.activeFocus && horizontalRow.currentIndex === index

                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: posterCard.isItemFocused ? "#222a3d" : "#131724"
                            border.color: posterCard.isItemFocused ? "#00bdff" : "#202636"
                            border.width: posterCard.isItemFocused ? 3 : 1
                            scale: posterCard.isItemFocused ? 1.08 : 1.0

                            Behavior on scale { NumberAnimation { duration: 120; easing.type: "OutCubic" } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                // Poster Image
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 8
                                    color: "#0a0c12"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: model.posterUrl
                                        fillMode: Image.PreserveAspectCrop
                                    }

                                    // Rating Badge
                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        width: 38
                                        height: 22
                                        radius: 4
                                        color: "#cc0f1424"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "★ " + model.rating
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#ffc107"
                                        }
                                    }
                                }

                                // Title Info
                                Text {
                                    Layout.fillWidth: true
                                    text: model.title
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: posterCard.isItemFocused ? "#ffffff" : "#c4c9da"
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }

                                RowLayout {
                                    Text {
                                        text: model.year
                                        font.pixelSize: 12
                                        color: "#8a90a6"
                                    }
                                    Text { text: "•"; font.pixelSize: 12; color: "#8a90a6" }
                                    Text {
                                        text: model.mediaType
                                        font.pixelSize: 12
                                        color: "#00a4dc"
                                        font.bold: true
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    horizontalRow.currentIndex = index
                                    categoryList.currentIndex = categoryRow.rowIndex
                                    mediaGridPage.itemSelected(horizontalRow.model.get(index))
                                }
                            }
                        }

                        // Spatial Navigation Listeners
                        Keys.onReturnPressed: {
                            mediaGridPage.itemSelected(horizontalRow.model.get(index))
                        }
                        Keys.onSpacePressed: {
                            mediaGridPage.itemSelected(horizontalRow.model.get(index))
                        }
                    }

                    // High-speed key navigation across rows
                    Keys.onUpPressed: function(event) {
                        if (categoryList.currentIndex > 0) {
                            categoryList.currentIndex--
                            categoryList.positionViewAtIndex(categoryList.currentIndex, ListView.Beginning)
                        }
                        event.accepted = true
                    }
                    Keys.onDownPressed: function(event) {
                        if (categoryList.currentIndex < categoryList.count - 1) {
                            categoryList.currentIndex++
                            categoryList.positionViewAtIndex(categoryList.currentIndex, ListView.Beginning)
                        }
                        event.accepted = true
                    }
                }
            }
        }
    }
}
