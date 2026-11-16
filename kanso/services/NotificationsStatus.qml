import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Mirrors Amber's robust in-memory notification history, with Kanso presentation.
Scope {
    id: root
    property var entries: []
    property int unreadCount: 0
    property int nextId: 0
    property int toastSerial: 0
    property var latestToast: null
    property bool doNotDisturb: false
    readonly property int limit: 40
    NotificationServer {
        id: broker
        keepOnReload: true
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = !n.transient
            root.receive(n)
        }
    }
    function receive(n) {
        const uid = ++nextId
        const item = { uid: uid, app: String(n.appName || "Application"),
                       title: String(n.summary || "Notification"),
                       body: String(n.body || ""),
                       time: Qt.formatTime(new Date(), "HH:mm"),
                       live: n, unread: !n.lastGeneration }
        n.closed.connect(function() { root.closed(uid) })
        if (!n.transient) {
            const arr = [item].concat(entries)
            while (arr.length > limit) {
                const removed = arr.pop()
                if (removed.live) removed.live.dismiss()
            }
            entries = arr
            unreadCount = entries.filter(v => v.unread).length
        }
        if (!doNotDisturb && !n.lastGeneration) {
            latestToast = { app:item.app, title:item.title, body:item.body, time:item.time }
            toastSerial += 1
        }
    }
    function closed(uid) {
        entries = entries.map(v => v.uid === uid ? {
            uid:v.uid, app:v.app, title:v.title, body:v.body, time:v.time,
            live:null, unread:v.unread
        } : v)
    }
    function markRead() {
        entries = entries.map(v => ({ uid:v.uid, app:v.app, title:v.title,
            body:v.body, time:v.time, live:v.live, unread:false }))
        unreadCount = 0
    }
    function dismiss(uid) {
        const matched = entries.find(v => v.uid === uid)
        entries = entries.filter(v => v.uid !== uid)
        unreadCount = entries.filter(v => v.unread).length
        if (matched && matched.live) matched.live.dismiss()
    }
    function invoke(uid, actionIndex) {
        const entry = entries.find(v => v.uid === uid)
        if (entry && entry.live && entry.live.actions.length > actionIndex)
            entry.live.actions[actionIndex].invoke()
    }
    function clearAll() {
        const old = entries
        entries = []
        unreadCount = 0
        for (const item of old) if (item.live) item.live.dismiss()
    }
}
