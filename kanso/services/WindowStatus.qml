import QtQuick
import Quickshell
import Quickshell.Io
import "AppIdentity.js" as Identity

// KWin remains the window authority; application keys are normalised once.
Scope {
    id: root
    property var applications: []
    readonly property string queryScript:
        "var result=[];var ws=workspace.stackingOrder;" +
        "for(var i=0;i<ws.length;i++){var w=ws[i];" +
        "if(w.deleted||w.skipTaskbar||w.specialWindow||(!w.normalWindow&&!w.dialog))continue;" +
        "result.push({id:String(w.internalId),caption:String(w.caption||'')," +
        "desktopFile:String(w.desktopFileName||''),resourceClass:String(w.resourceClass||'')," +
        "resourceName:String(w.resourceName||'')," +
        "active:Boolean(w.active),minimized:Boolean(w.minimized)});}" +
        "output_result(JSON.stringify(result));"

    function applySnapshot(raw) {
        let rows
        try { rows = JSON.parse(String(raw || "").trim()) }
        catch (e) { console.warn("Kanso WindowStatus: unexpected KWin output:", e); return }
        if (!Array.isArray(rows)) return
        const map = {}
        const seenIds = {}
        for (const w of rows) {
            const id = String(w.id || "")
            // One bar per actual KWin window, never per repeated record.
            if (!id || seenIds[id]) continue
            seenIds[id] = true
            const key = Identity.windowKey(w)
            if (!map[key]) map[key] = {
                key:key, desktopFile:String(w.desktopFile || ""),
                resourceClass:String(w.resourceClass || ""), resourceName:String(w.resourceName || ""),
                caption:String(w.caption || ""), active:false, minimized:true,
                windowCount:0, activeWindowId:"", representativeId:"", windows:[]
            }
            const app = map[key]
            app.windows.push({id:id, caption:String(w.caption || ""),
                minimized:!!w.minimized, active:!!w.active})
            app.windowCount = app.windows.length
            if (w.active) {
                app.active = true
                app.activeWindowId = id
                app.representativeId = id
                app.caption = String(w.caption || "")
            } else if (!app.representativeId) app.representativeId = id
            if (!w.minimized) app.minimized = false
            if (!app.desktopFile && w.desktopFile) app.desktopFile = String(w.desktopFile)
            if (!app.resourceClass && w.resourceClass) app.resourceClass = String(w.resourceClass)
            if (!app.resourceName && w.resourceName) app.resourceName = String(w.resourceName)
        }
        applications = Object.keys(map).sort().map(key => map[key])
    }
    function refresh() { if (!query.running) query.running = true }
    function refreshSoon(ms) { delay.interval = ms===undefined ? 300 : ms; delay.restart() }
    function activate(id) {
        if (id) { Quickshell.execDetached(["kdotool", "windowactivate", String(id)]); refreshSoon(300) }
    }
    function minimize(id) {
        if (id) { Quickshell.execDetached(["kdotool", "windowminimize", String(id)]); refreshSoon(300) }
    }
    function close(id) {
        if (id) { Quickshell.execDetached(["kdotool", "windowclose", String(id)]); refreshSoon(400) }
    }
    Process {
        id: query
        command: ["kdotool", "kwinscript", "--inline", root.queryScript]
        stdout: StdioCollector { onStreamFinished: root.applySnapshot(text) }
    }
    Timer { interval: 1200; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { id: delay; interval: 300; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()
}
