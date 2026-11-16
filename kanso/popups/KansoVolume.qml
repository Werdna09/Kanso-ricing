import QtQuick
import Quickshell
import "../components"

PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    required property var audio
    implicitWidth: 377
    implicitHeight: 514
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
            Text { text: "Zvuk"; color: root.palette.colors.text
                font.family: "Noto Sans"; font.pixelSize: 16; font.bold: true }
            Row { width: parent.width; spacing: 9
                KansoAction { width: 92; palette: root.palette
                    title: root.audio.muted ? "Ztlumeno" : "Zvuk"
                    selected: root.audio.muted
                    onInvoked: root.audio.toggleMute() }
                KansoSlider { width: parent.width - 156; palette: root.palette
                    anchors.verticalCenter: parent.verticalCenter
                    value: root.audio.volume; onChanged: value => root.audio.setVolume(value/100) }
                Text { width: 48; text: root.audio.volume + "%"; anchors.verticalCenter: parent.verticalCenter
                    color: root.palette.colors.text; font.family: "JetBrains Mono"; font.pixelSize: 12 }
            }
            Text { text: "Výstupní zařízení"; color: root.palette.colors.muted
                font.family: "Noto Sans"; font.pixelSize: 12 }
            Flickable { width: parent.width; height: 127; contentWidth: width
                contentHeight: audioOutputs.implicitHeight; clip: true
                Column { id: audioOutputs; width: parent.width; spacing: 6
                    Repeater { model: root.audio.outputs.slice(0,8)
                        delegate: KansoAction { required property var modelData
                            width: audioOutputs.width; palette: root.palette
                            title: modelData.description || modelData.name || "Výstup"
                            selected: root.audio.sink === modelData
                            onInvoked: root.audio.chooseOutput(modelData) }
                    }
                }
            }
            Text { text: "Mikrofon / vstup"; color: root.palette.colors.muted
                font.family: "Noto Sans"; font.pixelSize: 12 }
            KansoAction { width: parent.width; palette: root.palette
                title: root.audio.microphoneMuted ? "Mikrofon vypnut" : "Mikrofon zapnut"
                detail: root.audio.microphoneAvailable ? "Kliknutím změnit" : "Žádný vstup"
                enabled: root.audio.microphoneAvailable
                selected: root.audio.microphoneMuted
                onInvoked: root.audio.toggleMicrophone() }
            Flickable { width: parent.width; height: 86; contentWidth: width
                contentHeight: audioInputs.implicitHeight; clip: true
                Column { id: audioInputs; width: parent.width; spacing: 5
                    Repeater { model: root.audio.inputs.slice(0,6)
                        delegate: KansoAction { required property var modelData
                            width: audioInputs.width; palette: root.palette
                            title: modelData.description || modelData.name || "Vstup"
                            selected: root.audio.source === modelData
                            onInvoked: root.audio.chooseInput(modelData) }
                    }
                }
            }

        }
    }
}
