import QtQuick
import Quickshell

Scope {
    id: root
    required property var palette
    required property var notifications
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: popup
            required property var modelData
            screen: modelData
            anchors { top: true; right: true }
            margins { top: 56; right: 12 }
            implicitWidth: 350; implicitHeight: 106
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            color: "transparent"
            visible: false
            Connections { target: root.notifications
                function onToastSerialChanged() {
                    if (root.notifications.doNotDisturb) return
                    popup.visible = true
                    hideTimer.restart()
                }
            }
            Timer { id: hideTimer; interval: 5200; onTriggered: popup.visible = false }
            Rectangle {
                anchors.fill: parent; radius: 10
                color: root.palette.colors.background
                border { width: 1; color: root.palette.colors.accent }
                Column {
                    anchors { fill: parent; margins: 12 }
                    spacing: 5
                    Text { text: root.notifications.latestToast ? root.notifications.latestToast.app : ""
                        color: root.palette.colors.muted; font { family: "JetBrains Mono"; pixelSize: 10 } }
                    Text { width: parent.width; elide: Text.ElideRight
                        text: root.notifications.latestToast ? root.notifications.latestToast.title : ""
                        color: root.palette.colors.text; font { family: "JetBrains Mono"; pixelSize: 13; bold: true } }
                    Text { width: parent.width; wrapMode: Text.Wrap; textFormat: Text.PlainText
                        maximumLineCount: 2; elide: Text.ElideRight
                        text: root.notifications.latestToast ? root.notifications.latestToast.body : ""
                        color: root.palette.colors.muted; font { family: "JetBrains Mono"; pixelSize: 11 } }
                }
                MouseArea { anchors.fill: parent; onClicked: popup.visible = false }
            }
        }
    }
}
