import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// System icons live here, away from the main bar. Native menus remain accessible.
PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    implicitWidth: 294
    implicitHeight: Math.min(422, 60 + Math.max(1, SystemTray.items.values.length) * 44)
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX

    Rectangle {
        anchors.fill: parent
        radius: 11
        color: root.palette.colors.background
        border.width: 1
        border.color: root.palette.colors.border
        Column {
            anchors { fill: parent; margins: 13 }
            spacing: 8
            Text {
                text: "SYSTÉMOVÁ LIŠTA"
                font.family: "Noto Sans"
                font.pixelSize: 12
                font.bold: true
                color: root.palette.colors.text
            }
            Text {
                visible: SystemTray.items.values.length === 0
                text: "Žádné aplikace na pozadí"
                font.family: "Noto Sans"
                font.pixelSize: 11
                color: root.palette.colors.muted
            }
            Flickable {
                width: parent.width
                height: Math.max(0, root.height - 58)
                contentWidth: width
                contentHeight: entries.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: entries
                    width: parent.width
                    spacing: 3
                    Repeater {
                        model: SystemTray.items
                        delegate: Rectangle {
                            id: itemButton
                            required property var modelData
                            width: entries.width
                            readonly property string identity: (String(modelData.id || "") + " " + String(modelData.title || "")).toLowerCase()
                            readonly property bool updater: identity.includes("arch-update") || identity.includes("cachy-update") || identity.includes("arch update") || identity.includes("cachy update")
                            visible: !updater
                            height: visible ? 41 : 0
                            radius: 7
                            color: pointer.containsMouse ? root.palette.colors.surfaceAlt : root.palette.colors.surface
                            Row {
                                anchors { fill: parent; leftMargin: 10; rightMargin: 9 }
                                spacing: 10
                                Image {
                                    width: 24; height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    source: itemButton.modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                }
                                Text {
                                    width: itemButton.width - 58
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: itemButton.modelData.title || itemButton.modelData.id || "Aplikace"
                                    elide: Text.ElideRight
                                    color: root.palette.colors.text
                                    font.family: "Noto Sans"
                                    font.pixelSize: 11
                                }
                            }
                            MouseArea {
                                id: pointer
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    const tray = itemButton.modelData
                                    if (mouse.button === Qt.MiddleButton) {
                                        tray.secondaryActivate()
                                    } else if (mouse.button === Qt.RightButton || tray.onlyMenu) {
                                        if (tray.hasMenu) {
                                            const p = itemButton.mapToItem(null, 20, itemButton.height)
                                            tray.display(root, Math.round(p.x), Math.round(p.y))
                                        }
                                    } else {
                                        tray.activate()
                                    }
                                }
                                onWheel: wheel => {
                                    itemButton.modelData.scroll(wheel.angleDelta.y, false)
                                    wheel.accepted = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
