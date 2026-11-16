import QtQuick
import Quickshell
import Quickshell.Widgets

// Kanso Start: an actual Quickshell application menu, not a Rofi skin.
// All app data comes from the current system's .desktop entries.
PopupWindow {
    id: root
    required property Item anchorItem
    required property var palette
    property string query: ""
    property string category: "Vše"
    property string confirmAction: ""
    readonly property var categories: ["Vše", "Internet", "Vývoj", "Kancelář", "Multimédia", "Systém"]
    readonly property var favorites: [
        {name:"Firefox", lookup:"firefox", icon:"firefox"},
        {name:"Soubory", lookup:"org.kde.dolphin", icon:"system-file-manager"},
        {name:"Terminál", lookup:"Alacritty", icon:"utilities-terminal"},
        {name:"VS Code", lookup:"code", icon:"code"},
        {name:"Spotify", lookup:"spotify", icon:"spotify"},
        {name:"Nastavení", lookup:"systemsettings", icon:"preferences-system"}
    ]
    implicitWidth: 528
    implicitHeight: 622
    color: "transparent"
    grabFocus: true
    anchor.item: anchorItem
    // The popup grows upward/rightward from the launcher's top-left.
    // Move its LEFT edge 40px left and its BOTTOM edge 24px above that point.
    // Slide horizontally at screen edges, never flip beneath the dock.
    anchor.rect.x: -40
    anchor.rect.y: -12
    anchor.edges: Edges.Top | Edges.Left
    anchor.gravity: Edges.Top | Edges.Right
    anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY

    function matchesCategory(entry) {
        if (category === "Vše") return true
        const cats = entry.categories || []
        const mapping = {
            "Internet": ["Network", "WebBrowser", "Email", "InstantMessaging"],
            "Vývoj": ["Development", "IDE"],
            "Kancelář": ["Office", "Education"],
            "Multimédia": ["AudioVideo", "Audio", "Video", "Graphics", "Photography"],
            "Systém": ["System", "Settings", "Utility", "FileManager"]
        }
        return (mapping[category] || []).some(c => cats.indexOf(c) !== -1)
    }
    function matchesQuery(entry) {
        const q = query.trim().toLocaleLowerCase()
        if (!q) return true
        const text = [entry.name || "", entry.genericName || "", entry.comment || "",
                      ...(entry.keywords || [])].join(" ").toLocaleLowerCase()
        return text.indexOf(q) !== -1
    }
    function entryFor(name) {
        return DesktopEntries.byId(name) || DesktopEntries.byId(name + ".desktop") ||
               DesktopEntries.heuristicLookup(name)
    }
    function launchEntry(entry) {
        if (entry) {
            root.visible = false
            entry.execute()
        }
    }
    Timer {
        id: confirmationTimeout
        interval: 5000
        repeat: false
        onTriggered: root.confirmAction = ""
    }
    function action(name) {
        if (name === "settings") {
            confirmationTimeout.stop()
            confirmAction = ""
            root.visible = false
            Quickshell.execDetached(["systemsettings"])
        } else if (name === "lock") {
            confirmationTimeout.stop()
            confirmAction = ""
            root.visible = false
            Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "power", "lock"])
        } else if (name === "shutdown" || name === "reboot") {
            if (confirmAction === name) {
                confirmationTimeout.stop()
                root.visible = false
                confirmAction = ""
                Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "power", name])
            } else {
                confirmAction = name
                confirmationTimeout.restart()
            }
        }
    }
    onVisibleChanged: {
        if (visible) {
            query = ""
            category = "Vše"
            confirmAction = ""
            confirmationTimeout.stop()
            Qt.callLater(function() { if (root.visible) searchInput.forceActiveFocus() })
        }
    }

    ScriptModel {
        id: installedApps
        values: [...DesktopEntries.applications.values]
            .filter(a => a.name && root.matchesCategory(a) && root.matchesQuery(a))
            .sort((a, b) => (a.name || "").localeCompare(b.name || "", "cs"))
    }

    Rectangle {
        anchors.fill: parent
        radius: 15
        color: root.palette.colors.background
        border { width: 1; color: root.palette.colors.border }
        clip: true

        Column {
            anchors { fill: parent; margins: 18 }
            spacing: 8

            Row {
                width: parent.width
                height: 39
                spacing: 12
                Rectangle {
                    width: 38; height: 38; radius: 9
                    color: root.palette.colors.paper
                    Text {
                        anchors.centerIn: parent
                        text: "簡"
                        color: root.palette.colors.ink
                        font { family: "Noto Sans CJK JP"; pixelSize: 23 }
                    }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Text {
                        text: "KANSO  /  START"
                        color: root.palette.colors.text
                        font { family: "JetBrains Mono"; pixelSize: 14; bold: true; letterSpacing: 1 }
                    }
                    Text {
                        text: "JEDNODUŠE · PŘEHLEDNĚ · KLIDNĚ"
                        color: root.palette.colors.muted
                        font { family: "JetBrains Mono"; pixelSize: 9; letterSpacing: .4 }
                    }
                }
                Item { width: Math.max(1, parent.width - 360); height: 1 }
            }

            Rectangle {
                width: parent.width; height: 42; radius: 9
                color: root.palette.colors.surface
                border { color: searchInput.activeFocus ? root.palette.colors.accent : root.palette.colors.border; width: 1 }
                Row {
                    anchors { fill: parent; leftMargin: 13; rightMargin: 12 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        color: root.palette.colors.muted
                        font.pixelSize: 25
                    }
                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 45
                        color: root.palette.colors.text
                        selectedTextColor: root.palette.colors.ink
                        selectionColor: root.palette.colors.paper
                        font { family: "Noto Sans"; pixelSize: 13 }
                        clip: true
                        selectByMouse: true
                        text: root.query
                        onTextEdited: root.query = text
                        Keys.onEscapePressed: root.visible = false
                        Keys.onReturnPressed: if (installedApps.values.length) root.launchEntry(installedApps.values[0])
                        Keys.onEnterPressed: if (installedApps.values.length) root.launchEntry(installedApps.values[0])
                    }
                }
                Text {
                    visible: searchInput.text === ""
                    text: "Hledat aplikace…"
                    anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 45 }
                    color: root.palette.colors.muted
                    font { family: "Noto Sans"; pixelSize: 13 }
                    MouseArea { anchors.fill: parent; onClicked: searchInput.forceActiveFocus() }
                }
            }

            Text {
                text: "OBLÍBENÉ"
                color: root.palette.colors.muted
                font { family: "JetBrains Mono"; pixelSize: 10; bold: true; letterSpacing: .8 }
            }
            Grid {
                width: parent.width
                columns: 3
                rowSpacing: 6
                columnSpacing: 8
                Repeater {
                    model: root.favorites
                    delegate: Rectangle {
                        id: favorite
                        required property var modelData
                        readonly property var entry: root.entryFor(modelData.lookup)
                        width: (parent.width - 16) / 3
                        height: 47
                        radius: 8
                        color: favMouse.containsMouse ? root.palette.colors.surfaceAlt : root.palette.colors.surface
                        border {width: 1; color: root.palette.colors.border}
                        Row {
                            anchors { fill: parent; margins: 9 }
                            spacing: 10
                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 23
                                source: Quickshell.iconPath(favorite.entry && favorite.entry.icon ? favorite.entry.icon : favorite.modelData.icon,
                                                            "application-x-executable")
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 33
                                text: favorite.modelData.name
                                color: root.palette.colors.text
                                elide: Text.ElideRight
                                font { family: "Noto Sans"; pixelSize: 12; bold: true }
                            }
                        }
                        MouseArea {
                            id: favMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launchEntry(favorite.entry)
                        }
                    }
                }
            }

            Text {
                text: "APLIKACE"
                color: root.palette.colors.muted
                font { family: "JetBrains Mono"; pixelSize: 10; bold: true; letterSpacing: .8 }
            }
            Flickable {
                width: parent.width
                height: 35
                contentWidth: chips.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: chips; height: 33; spacing: 6
                    Repeater {
                        model: root.categories
                        delegate: Rectangle {
                            id: chip
                            required property string modelData
                            readonly property bool selected: root.category === modelData
                            width: chipLabel.implicitWidth + 22
                            height: 30
                            radius: 7
                            color: selected ? root.palette.colors.paper : root.palette.colors.surface
                            Text {
                                id: chipLabel; anchors.centerIn: parent
                                text: chip.modelData
                                color: chip.selected ? root.palette.colors.ink : root.palette.colors.text
                                font { family: "Noto Sans"; pixelSize: 11; bold: chip.selected }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: root.category = chip.modelData
                            }
                        }
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.palette.colors.border; opacity: .6 }
            ListView {
                id: appList
                width: parent.width
                height: 195
                model: installedApps
                clip: true
                spacing: 3
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    width: appList.width
                    height: 41
                    radius: 7
                    color: rowMouse.containsMouse ? root.palette.colors.surfaceAlt : "transparent"
                    Row {
                        anchors {fill: parent; leftMargin: 9; rightMargin: 9}
                        spacing: 11
                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 25
                            source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: appRow.width - 60
                                text: appRow.modelData.name
                                elide: Text.ElideRight
                                color: root.palette.colors.text
                                font { family: "Noto Sans"; pixelSize: 12; bold: true }
                            }
                            Text {
                                width: appRow.width - 60
                                text: appRow.modelData.genericName || appRow.modelData.comment || ""
                                elide: Text.ElideRight
                                color: root.palette.colors.muted
                                font { family: "Noto Sans"; pixelSize: 9 }
                            }
                        }
                    }
                    MouseArea {
                        id: rowMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.launchEntry(appRow.modelData)
                    }
                }
            }
            Rectangle { width: parent.width; height: 1; color: root.palette.colors.border; opacity: .6 }
            Row {
                width: parent.width
                height: 37
                spacing: 7
                Repeater {
                    model: [
                        {name:"Zamknout", command:"lock"},
                        {name:"Nastavení", command:"settings"},
                        {name:"Restart", command:"reboot"},
                        {name:"Vypnout", command:"shutdown"}
                    ]
                    delegate: Rectangle {
                        id: actionButton
                        required property var modelData
                        width: (parent.width - 21) / 4
                        height: 37; radius: 7
                        color: actionMouse.containsMouse ? root.palette.colors.surfaceAlt : root.palette.colors.surface
                        border {color: root.palette.colors.border; width: 1}
                        Text {
                            anchors.centerIn: parent
                            text: root.confirmAction === actionButton.modelData.command ? "POTVRDIT" : actionButton.modelData.name
                            color: root.confirmAction === actionButton.modelData.command ? root.palette.colors.danger : root.palette.colors.text
                            font { family: "Noto Sans"; pixelSize: 11; bold: root.confirmAction === actionButton.modelData.command }
                        }
                        MouseArea {
                            id: actionMouse; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.action(actionButton.modelData.command)
                        }
                    }
                }
            }
            Text {
                text: root.confirmAction ? "K opuštění relace je nutné druhé kliknutí." : "KANSO  ·  Minimalismus v pohybu"
                color: root.palette.colors.muted
                font { family: "JetBrains Mono"; pixelSize: 9 }
            }
        }
    }
}
