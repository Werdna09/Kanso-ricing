import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var network
    implicitWidth: 360
    implicitHeight: 460
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    anchor.edges: Edges.Bottom | Edges.Right
    anchor.gravity: Edges.Bottom | Edges.Left
    anchor.margins.top: 7
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.FlipX
    onVisibleChanged: { if (visible) { root.network.scan() } }
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
            Text { text: "Wi-Fi"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            Row {
                width: parent.width; spacing: 9
                KansoAction { width: 128; palette: root.palette
                    title: root.network.wifiEnabled ? "Wi-Fi zapnuta" : "Wi-Fi vypnuta"
                    selected: root.network.wifiEnabled
                    onInvoked: root.network.toggleWifi() }
                Text { width: parent.width - 143; anchors.verticalCenter: parent.verticalCenter
                    text: root.network.wifiConnected ? root.network.wifiName : "Nepřipojeno"
                    elide: Text.ElideRight; color: root.palette.colors.muted
                    font.family: "Noto Sans"; font.pixelSize: 12 }
            }
            Text { text: "Dostupné sítě"; color: root.palette.colors.muted
                font.family: "Noto Sans"; font.pixelSize: 12 }
            Flickable { width: parent.width; height: 243
                contentWidth: width; contentHeight: wifiList.implicitHeight
                clip: true; boundsBehavior: Flickable.StopAtBounds
                Column { id: wifiList; width: parent.width; spacing: 7
                    Repeater { model: root.network.wifiEnabled ? root.network.networks.slice(0,15) : []
                        delegate: KansoAction {
                            required property var modelData
                            width: wifiList.width; palette: root.palette
                            title: (modelData.connected ? "●  " : "") + modelData.name
                            detail: modelData.connected ? "Připojeno" : modelData.known ? "Uložená síť · Připojit" : "Vyžaduje nastavení"
                            selected: modelData.connected
                            onInvoked: {
                                if (modelData.connected) return
                                if (modelData.known) modelData.connect()
                                else Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"])
                            }
                        }
                    }
                }
            }
            KansoAction { width: parent.width; palette: root.palette
                title: "Nastavení sítí…"; detail: "Nové připojení, hesla a další možnosti"
                onInvoked: Quickshell.execDetached(["systemsettings", "kcm_networkmanagement"]) }

        }
    }
}
