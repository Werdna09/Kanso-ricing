import QtQuick
import Quickshell
import Quickshell.Widgets
import "../popups"
import "../services/AppIdentity.js" as Identity

// Kanso V3.3: dock + interactive window cards on hover (Wayland-safe).
// Windows are obtained from KWin: no screenshot / privacy-invasive capture.
Scope {
    id: root
    required property var palette
    required property var windowService

    readonly property var pinned: [
        {key:"firefox", label:"Firefox", icon:"firefox", command:["firefox"],
         lookups:["firefox", "org.mozilla.firefox"]},
        {key:"dolphin", label:"Dolphin", icon:"system-file-manager", command:["dolphin"],
         lookups:["org.kde.dolphin", "dolphin"]},
        {key:"alacritty", label:"Alacritty", icon:"Alacritty", command:["alacritty"],
         lookups:["Alacritty", "org.alacritty.Alacritty"]},
        {key:"code", label:"Visual Studio Code", icon:"code", command:["code"],
         lookups:["code", "code-oss", "visual-studio-code", "com.visualstudio.code"]}
    ]

    function desktopEntry(app) {
        const candidates = []
        function add(value) {
            const v = String(value || "").trim()
            if (v && candidates.indexOf(v) < 0) candidates.push(v)
        }
        for (const value of (app.lookups || [])) add(value)
        add(app.desktopFile)
        add(app.resourceClass)
        add(app.resourceName)
        add(app.key)
        for (const value of candidates) {
            let entry = DesktopEntries.byId(value)
            if (entry !== null) return entry
            if (!value.endsWith(".desktop")) {
                entry = DesktopEntries.byId(value + ".desktop")
                if (entry !== null) return entry
            }
        }
        for (const value of candidates) {
            const entry = DesktopEntries.heuristicLookup(value)
            if (entry !== null) return entry
        }
        return null
    }

    function launch(app) {
        const entry = desktopEntry(app)
        if (entry !== null) entry.execute()
        else if (app.command && app.command.length) Quickshell.execDetached(app.command)
        else Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "rofi"])
        windowService.refreshSoon(650)
    }

    function dockApplications() {
        const apps = windowService.applications || []
        const groups = {}
        const used = {}
        // Defensive consolidation also handles older WindowStatus snapshots.
        for (const app of apps) {
            const key = Identity.canonical(app.key) || Identity.canonical(app.desktopFile)
            if (!key) continue
            if (!groups[key]) groups[key] = []
            groups[key].push(app)
        }
        const result = []
        function build(key, sources, pin) {
            const windows = []
            const seen = {}
            let active = false
            let activeId = ""
            let representative = ""
            let desktopFile = ""
            let resourceClass = ""
            let resourceName = ""
            let caption = ""
            for (const app of sources) {
                active = active || !!app.active
                desktopFile = desktopFile || app.desktopFile || ""
                resourceClass = resourceClass || app.resourceClass || ""
                resourceName = resourceName || app.resourceName || ""
                caption = caption || app.caption || ""
                for (const win of app.windows || []) {
                    const id = String(win.id || "")
                    if (!id || seen[id]) continue
                    seen[id] = true
                    windows.push({id:id, caption:String(win.caption || ""),
                                  active:!!win.active, minimized:!!win.minimized})
                    if (win.active) activeId = id
                }
                if (app.activeWindowId) activeId = String(app.activeWindowId)
                if (!representative && app.representativeId) representative = String(app.representativeId)
            }
            const info = {
                key:key, desktopFile:desktopFile, resourceClass:resourceClass,
                resourceName:resourceName, lookups:pin ? pin.lookups : [],
                command:pin ? pin.command : []
            }
            const entry = root.desktopEntry(info)
            const label = pin ? pin.label : (entry ? entry.name : (caption || key))
            const icon = entry && entry.icon ? entry.icon :
                (pin ? pin.icon : (desktopFile || resourceClass || "application-x-executable"))
            const target = activeId || representative || (windows.length ? windows[0].id : "")
            const ids = windows.map(w => w.id + (w.active ? "a" : "") + (w.minimized ? "m" : "")).join(";")
            return {
                key:key, label:label, icon:icon, command:info.command, lookups:info.lookups,
                desktopFile:desktopFile, resourceClass:resourceClass, resourceName:resourceName,
                running:windows.length > 0, active:active, target:target,
                windows:windows, windowCount:windows.length,
                signature:key + "|" + windows.length + "|" + active + "|" + ids + "|" + label
            }
        }
        for (const pin of pinned) {
            const matches = []
            for (const key in groups) {
                for (const app of groups[key]) {
                    if (Identity.matches(app, pin.key)) {
                        if (!used[key]) matches.push(...groups[key])
                        used[key] = true
                        break
                    }
                }
            }
            result.push(build(pin.key, matches, pin))
        }
        for (const key in groups) {
            if (!used[key]) result.push(build(key, groups[key], null))
        }
        return result
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: dockWindow
            required property var modelData
            screen: modelData
            anchors { bottom:true; left:true; right:true }
            implicitHeight: 78
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            focusable: false
            property bool shown: false
            property bool contextOpen: false
            // Exactly one preview may be open across all app delegates.
            property string previewKey: ""
            function closePreview(key) {
                if (previewKey === key) previewKey = ""
                scheduleHide()
            }
            function reveal() { hideTimer.stop(); shown = true }
            function scheduleHide() { hideTimer.restart() }
            Timer {
                id: hideTimer
                interval: 850
                repeat: false
                onTriggered: {
                    if (!edgeHover.hovered && !dockHover.hovered && !dockWindow.contextOpen && dockWindow.previewKey === "")
                        dockWindow.shown = false
                }
            }
            mask: Region {
                x: pill.x; y: pill.y; width: pill.width; height: pill.height
                Region { x: 0; y: dockWindow.implicitHeight-4; width: dockWindow.width; height: 4 }
            }
            Rectangle {
                x: 0; y: dockWindow.implicitHeight-4
                width: dockWindow.width; height: 4; color: "transparent"
                HoverHandler {
                    id: edgeHover
                    onHoveredChanged: hovered ? dockWindow.reveal() : dockWindow.scheduleHide()
                }
            }
            Rectangle {
                id: pill
                width: Math.min(dockRow.implicitWidth + 22, dockWindow.width-22)
                height: 56; radius: 13
                x: (dockWindow.width-width)/2
                y: dockWindow.shown ? 10 : dockWindow.implicitHeight + 5
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                HoverHandler {
                    id: dockHover
                    onHoveredChanged: hovered ? dockWindow.reveal() : dockWindow.scheduleHide()
                }
                color: root.palette.colors.background
                border { width:1; color:root.palette.colors.border }
                opacity: .97
                Row {
                    id: dockRow
                    anchors.centerIn: parent
                    spacing: 4
                    Rectangle {
                        id: launcher
                        width: 46; height: 46; radius: 8
                        color: menuMouse.containsMouse ? root.palette.colors.surfaceAlt : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: "簡"
                            color: root.palette.colors.text
                            font { family: "Noto Sans CJK JP"; pixelSize: 22 }
                        }
                        MouseArea {
                            id: menuMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dockWindow.previewKey = ""
                                startMenu.visible = !startMenu.visible
                                if (startMenu.visible) dockWindow.reveal()
                            }
                        }
                        KansoStartMenu {
                            id: startMenu
                            anchorItem: launcher
                            palette: root.palette
                            visible: false
                            onVisibleChanged: {
                                if (visible) {
                                    dockWindow.contextOpen = true
                                    dockWindow.reveal()
                                } else {
                                    dockWindow.contextOpen = false
                                    dockWindow.scheduleHide()
                                }
                            }
                        }
                        PopupWindow {
                            visible: menuMouse.containsMouse && dockWindow.shown && !startMenu.visible
                            grabFocus: false
                            color: "transparent"
                            implicitWidth: 116; implicitHeight: 30
                            anchor.item: launcher
                            // Center the small tooltip over the launcher; leave a gap.
                            anchor.rect.x: Math.round((launcher.width - implicitWidth) / 2)
                            anchor.rect.y: -14
                            anchor.edges: Edges.Top | Edges.Left
                            anchor.gravity: Edges.Top | Edges.Right
                            anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
                            Rectangle {
                                anchors.fill: parent
                                radius: 7
                                color: root.palette.colors.background
                                border { width:1; color:root.palette.colors.border }
                                Text {
                                    anchors.centerIn:parent
                                    text:"Start menu"
                                    color:root.palette.colors.text
                                    font {family:"Noto Sans";pixelSize:11}
                                }
                            }
                        }
                    }
                    Rectangle {
                        width: 1; height: 27
                        anchors.verticalCenter:parent.verticalCenter
                        color:root.palette.colors.border
                        opacity:.6
                    }
                    ScriptModel { id:dockModel; values:root.dockApplications(); objectProp:"signature" }
                    Repeater {
                        model: dockModel
                        delegate: Rectangle {
                            id: appButton
                            required property var modelData
                            property int cycle: 0
                            // Hover waits 300 ms, then opens a row of cards for
                            // the app's actual KWin windows. No fake thumbnails.
                            readonly property int segments: Math.min(12, modelData.windowCount)
                            width: 47; height:46; radius:8
                            color: hit.containsMouse || context.visible ||
                                   dockWindow.previewKey === modelData.key ? root.palette.colors.surfaceAlt :
                                   (modelData.active ? root.palette.colors.surface : "transparent")
                            IconImage {
                                anchors.horizontalCenter:parent.horizontalCenter
                                anchors.verticalCenter:parent.verticalCenter
                                anchors.verticalCenterOffset:-3
                                implicitSize:28
                                source:Quickshell.iconPath(appButton.modelData.icon,"application-x-executable")
                                opacity:appButton.modelData.running?1:.76
                            }
                            Row {
                                anchors {bottom:parent.bottom;bottomMargin:3;horizontalCenter:parent.horizontalCenter}
                                spacing:2
                                Repeater {
                                    model:appButton.segments
                                    delegate: Rectangle {
                                        height:3; radius:1.5
                                        width:appButton.segments===1 ? 17 :
                                              Math.max(2,Math.floor((appButton.width-8-2*(appButton.segments-1))/appButton.segments))
                                        color:appButton.modelData.active ? root.palette.colors.accent : root.palette.colors.muted
                                    }
                                }
                            }
                            Timer {
                                id: previewDelay
                                interval: 320
                                repeat: false
                                onTriggered: {
                                    if (hit.containsMouse && !context.visible && !startMenu.visible) {
                                        dockWindow.previewKey = appButton.modelData.key
                                        dockWindow.reveal()
                                    }
                                }
                            }
                            // Permit the pointer to cross the small gap from dock
                            // to preview without making the preview flicker.
                            Timer {
                                id: previewDismiss
                                interval: 450
                                repeat: false
                                onTriggered: {
                                    if (!hit.containsMouse && !previewHover.hovered)
                                        dockWindow.closePreview(appButton.modelData.key)
                                }
                            }
                            MouseArea {
                                id:hit
                                anchors.fill:parent
                                hoverEnabled:true
                                acceptedButtons:Qt.LeftButton|Qt.MiddleButton|Qt.RightButton
                                cursorShape:Qt.PointingHandCursor
                                onContainsMouseChanged: {
                                    if (containsMouse) {
                                        dockWindow.reveal()
                                        previewDismiss.stop()
                                        if (dockWindow.previewKey !== appButton.modelData.key)
                                            dockWindow.previewKey = ""
                                        previewDelay.restart()
                                    } else {
                                        previewDelay.stop()
                                        previewDismiss.restart()
                                    }
                                }
                                onClicked: mouse => {
                                    previewDelay.stop()
                                    dockWindow.closePreview(appButton.modelData.key)
                                    if (mouse.button===Qt.RightButton) {
                                        context.visible=true
                                        return
                                    }
                                    if (mouse.button===Qt.MiddleButton) {
                                        root.launch(appButton.modelData)
                                        return
                                    }
                                    if (appButton.modelData.windowCount > 0) {
                                        const targets=appButton.modelData.windows
                                        let selected=targets[appButton.cycle % targets.length]
                                        if (targets.length===1) selected=targets[0]
                                        root.windowService.activate(selected.id)
                                        appButton.cycle++
                                    } else root.launch(appButton.modelData)
                                    root.windowService.refreshSoon(300)
                                }
                            }
                            // Quickshell PopupWindow is outside the dock's 78px
                            // PanelWindow and remains interactive beyond its mask.
                            PopupWindow {
                                id: preview
                                visible: dockWindow.previewKey === appButton.modelData.key &&
                                         dockWindow.shown && !context.visible && !startMenu.visible
                                grabFocus: false
                                color: "transparent"
                                readonly property int cardWidth: 188
                                readonly property int cardsShown: Math.min(4, appButton.modelData.windowCount)
                                implicitWidth: appButton.modelData.windowCount===0 ? 230 :
                                    Math.min(dockWindow.width-26, 26 + cardWidth*cardsShown +
                                             8*Math.max(0,cardsShown-1))
                                implicitHeight: appButton.modelData.windowCount===0 ? 77 : 153
                                anchor.item: appButton
                                // Center over the hovered ICON, not over the whole dock.
                                // Pull the card 20px above the icon for a clean gap.
                                anchor.rect.x: Math.round((appButton.width - implicitWidth) / 2)
                                anchor.rect.y: -10
                                anchor.edges: Edges.Top | Edges.Left
                                anchor.gravity: Edges.Top | Edges.Right
                                anchor.adjustment: PopupAdjustment.SlideX | PopupAdjustment.SlideY
                                onVisibleChanged: {
                                    if (visible) dockWindow.reveal()
                                    else dockWindow.scheduleHide()
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    color: root.palette.colors.background
                                    border {width:1; color:root.palette.colors.border}
                                    HoverHandler {
                                        id: previewHover
                                        onHoveredChanged: {
                                            if (hovered) {
                                                previewDismiss.stop()
                                                dockWindow.reveal()
                                            } else if (!hit.containsMouse) {
                                                previewDismiss.restart()
                                            }
                                        }
                                    }
                                    Column {
                                        anchors {fill:parent; margins:12}
                                        spacing: 8
                                        Row {
                                            width: parent.width
                                            height: 24
                                            spacing: 7
                                            IconImage {
                                                anchors.verticalCenter:parent.verticalCenter
                                                implicitSize: 19
                                                source: Quickshell.iconPath(appButton.modelData.icon, "application-x-executable")
                                            }
                                            Text {
                                                anchors.verticalCenter:parent.verticalCenter
                                                width: parent.width - 35
                                                text: appButton.modelData.label +
                                                    (appButton.modelData.windowCount > 0 ?
                                                    "  ·  " + appButton.modelData.windowCount +
                                                    (appButton.modelData.windowCount===1 ? " okno" :
                                                    (appButton.modelData.windowCount<5 ? " okna" : " oken")) : "")
                                                elide:Text.ElideRight
                                                color:root.palette.colors.text
                                                font {family:"Noto Sans"; pixelSize:12; bold:true}
                                            }
                                        }
                                        Text {
                                            visible: appButton.modelData.windowCount===0
                                            text:"Kliknutím spustit aplikaci"
                                            color:root.palette.colors.muted
                                            font {family:"Noto Sans";pixelSize:11}
                                        }
                                        Flickable {
                                            visible: appButton.modelData.windowCount > 0
                                            width: parent.width
                                            height: 98
                                            contentWidth: cards.implicitWidth
                                            contentHeight: height
                                            boundsBehavior: Flickable.StopAtBounds
                                            interactive: contentWidth > width
                                            clip: true
                                            Row {
                                                id: cards
                                                spacing: 8
                                                Repeater {
                                                    model: appButton.modelData.windows || []
                                                    delegate: Rectangle {
                                                        id: windowCard
                                                        required property var modelData
                                                        required property int index
                                                        width: preview.cardWidth
                                                        height: 94
                                                        radius: 8
                                                        color: winMouse.containsMouse ? root.palette.colors.surfaceAlt :
                                                            root.palette.colors.surface
                                                        border.width: 1
                                                        border.color: windowCard.modelData.active ? root.palette.colors.accent :
                                                            root.palette.colors.border
                                                        Rectangle {
                                                            width: 5; height: 5; radius:3
                                                            x: 10; y: 12
                                                            color: windowCard.modelData.active ? root.palette.colors.accent :
                                                                root.palette.colors.muted
                                                        }
                                                        Text {
                                                            x: 22; y: 8
                                                            text: windowCard.modelData.active ? "AKTIVNÍ" :
                                                                (windowCard.modelData.minimized ? "MINIMALIZOVÁNO" : "OKNO " + (windowCard.index+1))
                                                            font {family:"JetBrains Mono";pixelSize:9}
                                                            color: root.palette.colors.muted
                                                        }
                                                        Text {
                                                            x: 10; y: 27
                                                            width: parent.width - 20
                                                            height: 42
                                                            text: windowCard.modelData.caption || appButton.modelData.label
                                                            color: root.palette.colors.text
                                                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                                            maximumLineCount: 2
                                                            elide: Text.ElideRight
                                                            font {family:"Noto Sans";pixelSize:12;bold:true}
                                                        }
                                                        Text {
                                                            x: 10; y: 72
                                                            text: "Otevřít okno"
                                                            font {family:"Noto Sans";pixelSize:10}
                                                            color:root.palette.colors.muted
                                                        }
                                                        MouseArea {
                                                            id: winMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                root.windowService.activate(windowCard.modelData.id)
                                                                dockWindow.closePreview(appButton.modelData.key)
                                                            }
                                                        }
                                                        Rectangle {
                                                            width: 23; height: 23; radius: 5
                                                            x: parent.width-width-5; y: 4
                                                            z: 2
                                                            color: closeHover.containsMouse ? root.palette.colors.surfaceAlt : "transparent"
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "×"
                                                                color: root.palette.colors.text
                                                                font {family:"Noto Sans";pixelSize:18}
                                                            }
                                                            MouseArea {
                                                                id: closeHover
                                                                anchors.fill: parent
                                                                hoverEnabled: true
                                                                cursorShape: Qt.PointingHandCursor
                                                                onClicked: {
                                                                    root.windowService.close(windowCard.modelData.id)
                                                                    root.windowService.refreshSoon(400)
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
                            PopupWindow {
                                id:context
                                visible:false
                                color:"transparent"
                                grabFocus:true
                                onVisibleChanged: {
                                    dockWindow.contextOpen = visible
                                    if (visible) {
                                        dockWindow.previewKey = ""
                                        previewDelay.stop()
                                        dockWindow.reveal()
                                    }
                                    else dockWindow.scheduleHide()
                                }
                                implicitWidth:220
                                implicitHeight:150
                                anchor.item:appButton
                                anchor.rect.x: Math.round((appButton.width - implicitWidth) / 2)
                                anchor.rect.y: -18
                                anchor.edges:Edges.Top|Edges.Left
                                anchor.gravity:Edges.Top|Edges.Right
                                anchor.adjustment:PopupAdjustment.SlideX|PopupAdjustment.SlideY
                                Rectangle {
                                    anchors.fill:parent;radius:9;color:root.palette.colors.background
                                    border {width:1;color:root.palette.colors.border}
                                    Column {
                                        anchors {fill:parent;margins:9}
                                        spacing:5
                                        Text {
                                            text:appButton.modelData.label
                                            width:parent.width
                                            elide:Text.ElideRight
                                            color:root.palette.colors.text
                                            font {family:"Noto Sans";pixelSize:11;bold:true}
                                        }
                                        KansoAction {
                                            width:parent.width;palette:root.palette;title:"Nové okno"
                                            onInvoked:{root.launch(appButton.modelData);context.visible=false}
                                        }
                                        KansoAction {
                                            width:parent.width;palette:root.palette;title:"Minimalizovat"
                                            onInvoked:{root.windowService.minimize(appButton.modelData.target);context.visible=false}
                                        }
                                        KansoAction {
                                            width:parent.width;palette:root.palette;title:"Zavřít okno";danger:true
                                            onInvoked:{root.windowService.close(appButton.modelData.target);context.visible=false}
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
}
