import QtQuick
import Quickshell
import Quickshell.Io

// KDE KWin virtual desktops. Kanso owns this service; no Amber imports.
Scope {
    id: root
    property int current: 1
    function refresh() {
        if (!desktopQuery.running) desktopQuery.running = true
    }
    function switchTo(desktop) {
        if (desktop < 1 || desktop > 4) return
        Quickshell.execDetached(["qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.setCurrentDesktop", String(desktop)])
        root.current = desktop
    }
    Process {
        id: desktopQuery
        command: ["qdbus6", "org.kde.KWin", "/KWin", "org.kde.KWin.currentDesktop"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                if (!isNaN(n) && n >= 1 && n <= 4) root.current = n
            }
        }
    }
    Timer { interval: 1500; repeat: true; running: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()
}
