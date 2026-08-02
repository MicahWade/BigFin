import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQml 2.15

ApplicationWindow {
    id: rootWindow
    width: 1920
    height: 1080
    visible: true
    title: "Bigfin"

    Main {
        anchors.fill: parent
        focus: true
    }
}
