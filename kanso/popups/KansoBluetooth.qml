import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var bluetooth
    implicitWidth: 350
    implicitHeight: 420
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
            Text { text: "Bluetooth"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            KansoAction { width: parent.width; palette: root.palette
                title: root.bluetooth.enabled ? "Bluetooth zapnut" : "Bluetooth vypnut"
                detail: root.bluetooth.connectedCount + " připojených zařízení"
                selected: root.bluetooth.enabled
                onInvoked: root.bluetooth.toggle() }
            Text { text: "Spárovaná zařízení"; color: root.palette.colors.muted
                font.family: "Noto Sans"; font.pixelSize: 12 }
            Flickable { width: parent.width; height: 201
                contentWidth: width; contentHeight: deviceList.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                Column { id: deviceList; width: parent.width; spacing: 7
                    Repeater { model: root.bluetooth.enabled ? root.bluetooth.devices.filter(d=>d.paired).slice(0,12) : []
                        delegate: KansoAction {
                            required property var modelData
                            width: deviceList.width; palette: root.palette
                            title: modelData.name || "Bluetooth zařízení"
                            detail: modelData.connected ? "Připojeno · Kliknutím odpojit" : "Kliknutím připojit"
                            selected: modelData.connected
                            onInvoked: root.bluetooth.toggleDevice(modelData)
                        }
                    }
                }
            }
            Row { width: parent.width; spacing: 8
                KansoAction { width: (parent.width-8)/2; palette: root.palette
                    title: "Vyhledat"; onInvoked: root.bluetooth.discover() }
                KansoAction { width: (parent.width-8)/2; palette: root.palette
                    title: "Nastavení…"
                    onInvoked: Quickshell.execDetached(["systemsettings", "kcm_bluetooth"]) }
            }

        }
    }
}
