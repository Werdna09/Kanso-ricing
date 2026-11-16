import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int percentage: -1
    property bool available: percentage >= 0
    function refresh() { if (!query.running) query.running = true }
    function setPercentage(value) {
        if (!available) return
        const next = Math.round(Math.max(1, Math.min(100, value)))
        Quickshell.execDetached(["brightnessctl", "set", next + "%"])
        percentage = next
        delayedRefresh.restart()
    }
    Process {
        id: query
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = text.match(/(\d+)%/)
                root.percentage = match ? Number(match[1]) : -1
            }
        }
    }
    Timer { id: delayedRefresh; interval: 600; onTriggered: root.refresh() }
    Timer { interval: 12000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()
}
