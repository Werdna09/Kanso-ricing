import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var brightness
    implicitWidth: 362
    implicitHeight: 309
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    onVisibleChanged: { if (visible) { root.brightness.refresh() } }
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
            Text { text: "Jas a vzhled"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            Text { text: "Jas displeje"; color: root.palette.colors.muted
                font.family: "Noto Sans"; font.pixelSize: 12 }
            Row { width: parent.width; spacing: 11
                KansoSlider { width: parent.width-63; palette: root.palette
                    enabled: root.brightness.available; value: root.brightness.percentage < 0 ? 0 : root.brightness.percentage
                    onChanged: value => root.brightness.setPercentage(value) }
                Text { width: 52; text: root.brightness.available ? root.brightness.percentage + "%" : "N/A"
                    anchors.verticalCenter: parent.verticalCenter; color: root.palette.colors.text
                    font.family: "JetBrains Mono"; font.pixelSize: 12 }
            }
            KansoAction { width: parent.width; palette: root.palette
                title: root.palette.mode === "night" ? "Noční režim" : "Denní režim"
                detail: "Přepnout krajinu, barvy KDE a aplikace"
                selected: root.palette.mode === "night"
                onInvoked: root.palette.toggleMode() }
            KansoAction { width: parent.width; palette: root.palette
                title: root.palette.autoMode ? "Automaticky 07–19 · ZAP" : "Automaticky 07–19 · VYP"
                detail: "Ráno den, večer noc; ruční volba automatiku vypne"
                selected: root.palette.autoMode
                onInvoked: root.palette.toggleAutomatic() }
            Text { width: parent.width; wrapMode: Text.Wrap
                text: "Jas displeje a Night Color zůstávají v režii KDE."
                color: root.palette.colors.muted; font.family: "Noto Sans"; font.pixelSize: 11 }

        }
    }
}
