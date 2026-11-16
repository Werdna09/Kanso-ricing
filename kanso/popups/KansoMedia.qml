import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var media
    implicitWidth: 378
    implicitHeight: 140
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.palette.colors.background
        border.width: 1
        border.color: root.palette.colors.border
        clip: true
        Column {
            anchors { fill: parent; margins: 17 }
            spacing: 11
            Text { text: "Přehrávání"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            Text { width: parent.width; elide: Text.ElideRight
                text: root.media.available ? root.media.displayText : "Žádný aktivní přehrávač"
                color: root.palette.colors.text; font.family: "Noto Sans"; font.pixelSize: 12 }
            Row { width: parent.width; spacing: 8
                KansoAction { width: (parent.width - 16)/3; palette: root.palette
                    title: "Předchozí"; enabled: root.media.available; onInvoked: root.media.previous() }
                KansoAction { width: (parent.width - 16)/3; palette: root.palette
                    title: root.media.playing ? "Pauza" : "Přehrát"
                    enabled: root.media.available; onInvoked: root.media.togglePlaying() }
                KansoAction { width: (parent.width - 16)/3; palette: root.palette
                    title: "Další"; enabled: root.media.available; onInvoked: root.media.next() }
            }

        }
    }
}
