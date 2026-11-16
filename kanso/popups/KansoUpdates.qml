import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var updates
    required property var stats
    implicitWidth: 355
    implicitHeight: 266
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    onVisibleChanged: { if (visible) { root.updates.refresh(); root.stats.refresh() } }
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: root.palette.colors.background
        border.width: 1
        border.color: root.palette.colors.border
        clip: true
        Column {
            anchors { fill: parent; margins: 17 }
            spacing: 10
            Text {
                text: "CachyOS · Aktualizace"
                color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true
            }
            Text {
                text: root.updates.totalCount > 0 ?
                      "Připraveno " + root.updates.totalCount + " aktualizací" : "Žádné známé aktualizace"
                color: root.palette.colors.muted
                font.family: "JetBrains Mono"; font.pixelSize: 12
            }
            Row {
                width: parent.width; spacing: 8
                KansoAction { width: (parent.width - 8) / 2; palette: root.palette
                    title: "Repozitáře: " + root.updates.repoCount; enabled: false }
                KansoAction { width: (parent.width - 8) / 2; palette: root.palette
                    title: "AUR: " + root.updates.aurCount; enabled: false }
            }
            KansoAction {
                width: parent.width; palette: root.palette
                title: "Zkontrolovat aktualizace"
                detail: "Načíst dostupné balíčky znovu"
                onInvoked: root.updates.refresh()
            }
            KansoAction {
                width: parent.width; palette: root.palette
                title: "Otevřít aktualizace v terminálu"
                detail: "Cachy-Update · výběr a potvrzení balíčků"
                onInvoked: {
                    Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "updates", "--launch"])
                    root.visible = false
                }
            }
            Text {
                text: "CPU " + root.stats.cpu + "%  ·  RAM " + root.stats.memory + "%"
                color: root.palette.colors.muted
                font.family: "JetBrains Mono"; font.pixelSize: 11
            }
        }
    }
}
