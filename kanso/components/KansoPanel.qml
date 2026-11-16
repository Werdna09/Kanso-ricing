import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../popups"

// Kanso 3.1: three independent groups of small, floating capsules.
// No full-width colored slab, no distro branding, no pixel-fantasy chrome.
Scope {
    id: root
    required property var palette
    required property var workspaces
    required property var audio
    required property var network
    required property var bluetooth
    required property var battery
    required property var brightness
    required property var media
    required property var keyboard
    required property var updates
    required property var stats
    required property var notifications

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 60
            exclusiveZone: 60
            color: "transparent"
            // Clicks on the empty space between capsules reach the desktop/window.
            mask: Region {
                item: leftItems
                Region { item: centreItems }
                Region { item: rightItems }
            }
            readonly property bool compact: width < 1750
            readonly property bool narrow: width < 1240
            readonly property bool tiny: width < 1050

            function closePopups() {
                calendarPopup.visible = false
                trayPopup.visible = false
                wifiPopup.visible = false
                bluetoothPopup.visible = false
                volumePopup.visible = false
                batteryPopup.visible = false
                brightnessPopup.visible = false
                updatesPopup.visible = false
                mediaPopup.visible = false
                notificationPopup.visible = false
                powerPopup.visible = false
            }
            function togglePopup(popup) {
                const opening = !popup.visible
                closePopups()
                popup.visible = opening
            }
            SystemClock { id: clock; precision: SystemClock.Minutes }

            // Left: only identity and workspaces. Deliberate whitespace between groups.
            Row {
                id: leftItems
                anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: 7
                Rectangle {
                    width: 82; height: 40; radius: 9
                    color: logoMouse.containsMouse ? root.palette.colors.hover : root.palette.colors.card
                    border { width: 1; color: root.palette.colors.cardBorder }
                    Text {
                        anchors.centerIn: parent
                        text: "KANSO"
                        color: root.palette.colors.ink
                        font.family: "Noto Sans"
                        font.pixelSize: 13; font.bold: true; font.letterSpacing: 1.2
                    }
                    MouseArea {
                        id: logoMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "rofi"])
                    }
                }
                Row {
                    spacing: 4
                    Repeater {
                        model: 4
                        delegate: Rectangle {
                            id: desktop
                            required property int index
                            readonly property int number: index + 1
                            readonly property bool active: root.workspaces.current === number
                            width: 36; height: 40; radius: 9
                            color: active ? root.palette.colors.ink :
                                   (desktopPointer.containsMouse ? root.palette.colors.hover : root.palette.colors.card)
                            border.width: 1
                            border.color: active ? root.palette.colors.ink : root.palette.colors.cardBorder
                            Text {
                                anchors.centerIn: parent
                                text: String(desktop.number).padStart(2, "0")
                                color: desktop.active ? root.palette.colors.paper : root.palette.colors.ink
                                font.family: "JetBrains Mono"; font.pixelSize: 12
                                font.bold: desktop.active
                            }
                            MouseArea {
                                id: desktopPointer; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.workspaces.switchTo(desktop.number)
                            }
                        }
                    }
                }
            }

            // Centre: clock and optional media, as independent chips.
            Row {
                id: centreItems
                anchors.centerIn: parent
                spacing: 7
                visible: !panel.tiny
                KansoPanelButton {
                    id: mediaButton
                    visible: !panel.compact && root.media.available
                    palette: root.palette; icon: "music"; label: root.media.displayText
                    buttonWidth: 190; selected: mediaPopup.visible
                    onInvoked: panel.togglePopup(mediaPopup)
                    KansoMedia { id: mediaPopup; anchorItem: mediaButton
                        palette: root.palette; media: root.media; visible: false }
                }
                Rectangle {
                    id: clockButton
                    width: 106; height: 40; radius: 9
                    color: clockPointer.containsMouse || calendarPopup.visible
                           ? root.palette.colors.hover : root.palette.colors.card
                    border { width: 1; color: root.palette.colors.cardBorder }
                    Text {
                        anchors.centerIn: parent
                        text: Qt.formatTime(clock.date, "HH:mm")
                        font.family: "JetBrains Mono"; font.pixelSize: 15; font.bold: true
                        color: root.palette.colors.ink
                    }
                    MouseArea {
                        id: clockPointer; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panel.togglePopup(calendarPopup)
                    }
                    KansoCalendar { id: calendarPopup; anchorItem: clockButton
                        palette: root.palette; visible: false }
                }
                KansoPanelButton {
                    id: notificationButton
                    palette: root.palette
                    icon: root.notifications.unreadCount > 0 ? "bell-dot" : "bell"
                    selected: notificationPopup.visible
                    onInvoked: panel.togglePopup(notificationPopup)
                    KansoNotifications { id: notificationPopup; anchorItem: notificationButton
                        palette: root.palette; notifications: root.notifications; visible: false }
                }
            }

            // One integrated update entry. Other applications retain the system tray.
            readonly property bool hasOtherTrayItems: {
                const entries = SystemTray.items.values
                for (let i = 0; i < entries.length; i++) {
                    const entry = entries[i]
                    const identity = (String(entry.id || "") + " " + String(entry.title || "")).toLowerCase()
                    if (!identity.includes("cachy-update") && !identity.includes("arch-update")
                        && !identity.includes("arch update") && !identity.includes("cachy update")) return true
                }
                return false
            }
            // Right: clear status glyphs. Bluetooth ON and OFF must never look identical.
            Row {
                id: rightItems
                anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                spacing: panel.tiny ? 3 : 6
                KansoPanelButton {
                    id: trayButton
                    visible: panel.hasOtherTrayItems && !panel.tiny
                    palette: root.palette; icon: "tray"; selected: trayPopup.visible
                    onInvoked: panel.togglePopup(trayPopup)
                    KansoTray { id: trayPopup; anchorItem: trayButton
                        palette: root.palette; visible: false }
                }
                KansoPanelButton {
                    id: updateButton
                    palette: root.palette; icon: "update"
                    label: !panel.compact && root.updates.totalCount > 0 ? String(root.updates.totalCount) : ""
                    buttonWidth: !panel.compact && root.updates.totalCount > 0 ? 65 : 42
                    selected: updatesPopup.visible
                    onInvoked: panel.togglePopup(updatesPopup)
                    KansoUpdates { id: updatesPopup; anchorItem: updateButton
                        palette: root.palette; updates: root.updates; stats: root.stats; visible: false }
                }
                KansoPanelButton {
                    id: wifiButton
                    palette: root.palette
                    icon: root.network.wifiConnected ? "wifi" : "wifi-off"
                    inactiveState: !root.network.wifiEnabled
                    activeState: root.network.wifiConnected
                    showState: true
                    selected: wifiPopup.visible
                    onInvoked: panel.togglePopup(wifiPopup)
                    KansoWifi { id: wifiPopup; anchorItem: wifiButton
                        palette: root.palette; network: root.network; visible: false }
                }
                KansoPanelButton {
                    id: btButton
                    palette: root.palette
                    icon: root.bluetooth.enabled ? "bluetooth" : "bluetooth-off"
                    label: !panel.compact ? (root.bluetooth.enabled ? "ON" : "OFF") : ""
                    buttonWidth: !panel.compact ? 79 : 42
                    inactiveState: !root.bluetooth.enabled
                    activeState: root.bluetooth.enabled
                    showState: true
                    selected: bluetoothPopup.visible
                    onInvoked: panel.togglePopup(bluetoothPopup)
                    KansoBluetooth { id: bluetoothPopup; anchorItem: btButton
                        palette: root.palette; bluetooth: root.bluetooth; visible: false }
                }
                KansoPanelButton {
                    id: volumeButton
                    palette: root.palette; icon: root.audio.muted ? "volume-muted" : "volume"
                    label: !panel.narrow ? (root.audio.muted ? "MUTE" : root.audio.volume + "%") : ""
                    buttonWidth: panel.narrow ? 42 : 86
                    selected: volumePopup.visible
                    onInvoked: panel.togglePopup(volumePopup)
                    onScrolled: delta => {
                        if (delta > 0) root.audio.increase()
                        else if (delta < 0) root.audio.decrease()
                    }
                    KansoVolume { id: volumePopup; anchorItem: volumeButton
                        palette: root.palette; audio: root.audio; visible: false }
                }
                KansoPanelButton {
                    id: batteryButton
                    visible: root.battery.available
                    palette: root.palette; icon: "battery"
                    label: !panel.compact ? root.battery.percentage + "%" : ""
                    buttonWidth: !panel.compact ? 87 : 42
                    selected: batteryPopup.visible
                    onInvoked: panel.togglePopup(batteryPopup)
                    KansoBattery { id: batteryPopup; anchorItem: batteryButton
                        palette: root.palette; battery: root.battery; visible: false }
                }
                KansoPanelButton {
                    id: appearanceButton
                    palette: root.palette; icon: root.palette.mode === "night" ? "moon" : "sun"
                    selected: brightnessPopup.visible
                    onInvoked: panel.togglePopup(brightnessPopup)
                    KansoBrightness { id: brightnessPopup; anchorItem: appearanceButton
                        palette: root.palette; brightness: root.brightness; visible: false }
                }
                Rectangle {
                    id: keyboardButton
                    width: root.keyboard.displayLabel.length > 4 ? 76 : 58
                    height: 40; radius: 9
                    color: keyboardPointer.containsMouse ? root.palette.colors.hover : root.palette.colors.card
                    border { width: 1; color: root.palette.colors.cardBorder }
                    Text {
                        anchors.centerIn: parent; text: root.keyboard.displayLabel
                        color: root.palette.colors.ink
                        font.family: "JetBrains Mono"; font.pixelSize: 12; font.bold: true
                    }
                    MouseArea {
                        id: keyboardPointer; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.keyboard.nextLayout()
                    }
                }
                KansoPanelButton {
                    id: powerButton
                    palette: root.palette; icon: "power"
                    selected: powerPopup.visible
                    onInvoked: panel.togglePopup(powerPopup)
                    KansoPower { id: powerPopup; anchorItem: powerButton
                        palette: root.palette; visible: false }
                }
            }
        }
    }
}
