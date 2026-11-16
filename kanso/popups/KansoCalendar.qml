import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    property date viewed: new Date()
    implicitWidth: 290; implicitHeight: 381
    color: "transparent"; grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Left
    anchor.gravity: Edges.Bottom | Edges.Right
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    readonly property int offset: (new Date(viewed.getFullYear(),viewed.getMonth(),1).getDay()+6)%7
    function shift(n) { viewed = new Date(viewed.getFullYear(), viewed.getMonth()+n, 1) }
    Rectangle {
        anchors.fill: parent; radius: 12
        color: root.palette.colors.background
        border { width: 1; color: root.palette.colors.border }
        Column {
            anchors { fill: parent; margins: 15 }
            spacing: 13
            Row {
                width: parent.width; spacing: 14
                KansoAction { width: 35; palette: root.palette; title: "‹"; onInvoked: root.shift(-1) }
                Text { width: parent.width-112; height: 34; verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDate(root.viewed, "MMMM yyyy")
                    color: root.palette.colors.text; font { family: "JetBrains Mono"; pixelSize: 13 } }
                KansoAction { width: 35; palette: root.palette; title: "›"; onInvoked: root.shift(1) }
            }
            Grid {
                columns: 7; rowSpacing: 5; columnSpacing: 1
                Repeater {
                    model: ["Po","Út","St","Čt","Pá","So","Ne"]
                    Text { required property var modelData; width: 35; height: 19
                        text: modelData; horizontalAlignment: Text.AlignHCenter
                        color: root.palette.colors.muted; font { family: "JetBrains Mono"; pixelSize: 10 } }
                }
                Repeater {
                    model: 42
                    delegate: Rectangle {
                        required property int index
                        readonly property int dayNum: index - root.offset + 1
                        readonly property int monthLength: new Date(root.viewed.getFullYear(),root.viewed.getMonth()+1,0).getDate()
                        readonly property bool valid: dayNum>=1 && dayNum<=monthLength
                        readonly property date today: new Date()
                        readonly property bool now: valid && dayNum===today.getDate() && root.viewed.getMonth()===today.getMonth() && root.viewed.getFullYear()===today.getFullYear()
                        width: 35; height: 26; radius: 5
                        color: now ? root.palette.colors.accent : "transparent"
                        Text { anchors.centerIn: parent; text: valid ? dayNum : ""
                            color: now ? root.palette.colors.ink : root.palette.colors.text
                            font { family: "JetBrains Mono"; pixelSize: 11 } }
                    }
                }
            }
            KansoAction { width: parent.width; palette: root.palette; title: "Dnes"
                onInvoked: root.viewed = new Date() }
        }
    }
}
