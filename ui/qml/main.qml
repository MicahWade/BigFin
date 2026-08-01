import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15
import org.kde.kirigami 2.20 as Kirigami

ApplicationWindow {
    id: rootWindow
    title: "Bigfin"
    width: 1920
    height: 1080
    visible: true

    palette.window: "#0b0e17"
    palette.windowText: "#ffffff"
    palette.base: "#0f172a"
    palette.text: "#ffffff"
    palette.highlight: "#38bdf8"
    palette.highlightedText: "#ffffff"

    Main {
        anchors.fill: parent
        focus: true
    }
}
