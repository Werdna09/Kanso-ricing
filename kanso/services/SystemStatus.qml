import QtQuick
import Quickshell
import Quickshell.Io

// Derived from the native /proc counters; no psutil or hard-coded thermal zone.
Scope {
    id: root
    property int cpu: 0
    property int memory: 0
    property string memoryDetail: ""
    property double lastTotal: 0
    property double lastIdle: 0
    function refresh() { if (!snapshot.running) snapshot.running = true }
    Process {
        id: snapshot
        command: [Quickshell.shellDir + "/native/bin/kanso-native", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text.trim())
                    if (v.total > root.lastTotal) {
                        const dt = v.total - root.lastTotal
                        const di = v.idle - root.lastIdle
                        root.cpu = Math.max(0, Math.min(100, Math.round(100 * (dt-di)/dt)))
                    }
                    root.lastTotal = v.total
                    root.lastIdle = v.idle
                    root.memory = Math.round(v.memory_percent)
                    root.memoryDetail = v.memory_used_gib.toFixed(1) + " / " + v.memory_total_gib.toFixed(1) + " GiB"
                } catch (e) { console.warn("Kanso system stats:", e) }
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()
}
