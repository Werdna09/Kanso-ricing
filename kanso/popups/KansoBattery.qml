import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var battery
    implicitWidth: 320
    implicitHeight: 184
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
            Text { text: "Baterie"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            Text { text: root.battery.available ? root.battery.percentage + "%" : "Baterie nedostupná"
                color: root.palette.colors.text; font.family: "JetBrains Mono"
                font.pixelSize: 32; font.bold: true }
            Text { visible: root.battery.available
                text: root.battery.charging ? "Nabíjení" : "Napájení z baterie / připojeného zdroje"
                color: root.palette.colors.muted; font.family: "Noto Sans"; font.pixelSize: 12 }
            KansoAction { width: parent.width; palette: root.palette
                title: "Nastavení napájení…"; onInvoked: Quickshell.execDetached(["systemsettings", "kcm_powerdevilprofilesconfig"]) }

        }
    }
}
