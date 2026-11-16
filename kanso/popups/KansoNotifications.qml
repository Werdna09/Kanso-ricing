import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var notifications
    implicitWidth: 398
    implicitHeight: 475
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    onVisibleChanged: if (visible) notifications.markRead()
    Rectangle {
        anchors.fill: parent; radius: 12
        color: root.palette.colors.background
        border { width: 1; color: root.palette.colors.border }
        Column {
            anchors { fill: parent; margins: 16 }
            spacing: 10
            Text { text: "KANSO  /  OZNÁMENÍ"; color: root.palette.colors.text
                font { family: "JetBrains Mono"; pixelSize: 14; bold: true } }
            Row {
                width: parent.width; spacing: 8
                KansoAction { width: (parent.width-8)/2; palette: root.palette
                    title: root.notifications.doNotDisturb ? "Nerušit: ZAP" : "Nerušit: VYP"
                    selected: root.notifications.doNotDisturb
                    onInvoked: root.notifications.doNotDisturb = !root.notifications.doNotDisturb }
                KansoAction { width: (parent.width-8)/2; palette: root.palette
                    title: "Vymazat vše"; onInvoked: root.notifications.clearAll() }
            }
            Text { visible: root.notifications.entries.length === 0
                text: "Žádná oznámení v této relaci."; color: root.palette.colors.muted
                font { family: "JetBrains Mono"; pixelSize: 11 } }
            Flickable {
                width: parent.width; height: parent.height - 100
                contentWidth: width; contentHeight: stack.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: stack; width: parent.width; spacing: 7
                    Repeater {
                        model: root.notifications.entries
                        delegate: Rectangle {
                            id: itemCard
                            required property var modelData
                            width: stack.width
                            height: texts.implicitHeight + actions.implicitHeight + 22
                            radius: 8; color: root.palette.colors.surface
                            Column {
                                id: texts; anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                                spacing: 3
                                Row {
                                    width: parent.width; spacing: 8
                                    Text { width: parent.width-35; elide: Text.ElideRight
                                        text: itemCard.modelData.app + " · " + itemCard.modelData.time
                                        color: root.palette.colors.muted
                                        font { family: "JetBrains Mono"; pixelSize: 10 } }
                                    Text { text: "×"; color: root.palette.colors.text; font.pixelSize: 16
                                        MouseArea { anchors.fill: parent; onClicked: root.notifications.dismiss(itemCard.modelData.uid) } }
                                }
                                Text { text: itemCard.modelData.title; width: parent.width
                                    wrapMode: Text.Wrap; textFormat: Text.PlainText
                                    color: root.palette.colors.text; font { family: "JetBrains Mono"; pixelSize: 12; bold: true } }
                                Text { visible: itemCard.modelData.body.length > 0
                                    text: itemCard.modelData.body; width: parent.width; wrapMode: Text.Wrap
                                    textFormat: Text.PlainText; maximumLineCount: 3; elide: Text.ElideRight
                                    color: root.palette.colors.muted; font { family: "JetBrains Mono"; pixelSize: 11 } }
                            }
                            Row {
                                id: actions
                                anchors { top: texts.bottom; topMargin: 4; left: parent.left; leftMargin: 10 }
                                spacing: 6
                                Repeater {
                                    model: itemCard.modelData.live ? itemCard.modelData.live.actions : []
                                    delegate: KansoAction {
                                        required property var modelData
                                        required property int index
                                        width: Math.min(135, Math.max(65, label.implicitWidth + 20))
                                        palette: root.palette; title: modelData.text || "Akce"
                                        onInvoked: root.notifications.invoke(itemCard.modelData.uid, index)
                                        Text { id: label; text: parent.title; visible: false }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
