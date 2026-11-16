import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    property string pending: ""
    implicitWidth: 268; implicitHeight: 344
    color: "transparent"; grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    onVisibleChanged: if (!visible) pending = ""
    readonly property var actions: [
        {id:"lock", title:"Zamknout"}, {id:"suspend",title:"Uspat"},
        {id:"logout",title:"Odhlásit"}, {id:"reboot",title:"Restartovat"},
        {id:"shutdown",title:"Vypnout"}
    ]
    Rectangle {
        anchors.fill: parent; radius: 12; color: root.palette.colors.background
        border { width: 1; color: root.palette.colors.border }
        Column {
            anchors { fill: parent; margins: 15 }
            spacing: 8
            Text { text: "KANSO  /  SYSTÉM"; color: root.palette.colors.text
                font { family: "JetBrains Mono"; pixelSize: 13; bold: true } }
            Repeater {
                model: root.actions
                KansoAction { required property var modelData
                    width: parent.width; palette: root.palette
                    title: modelData.title; selected: root.pending === modelData.id
                    onInvoked: root.pending = modelData.id }
            }
            Text { text: root.pending === "" ? "Vyber akci." : "Potvrdit: " + root.pending + "?"
                color: root.palette.colors.muted; font { family: "JetBrains Mono"; pixelSize: 10 } }
            Row {
                width: parent.width; spacing: 8
                KansoAction { width: (parent.width-8)/2; palette: root.palette; title: "Zrušit"
                    onInvoked: root.visible = false }
                KansoAction { width: (parent.width-8)/2; palette: root.palette
                    title: "Potvrdit"; danger: true
                    onInvoked: {
                        if (!root.pending) return
                        const name = root.pending
                        root.visible = false
                        Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "power", name])
                    }
                }
            }
        }
    }
}
