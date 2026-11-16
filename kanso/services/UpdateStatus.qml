import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int repoCount: 0
    property int aurCount: 0
    readonly property int totalCount: repoCount + aurCount
    function countLines(s) {
        const content = String(s || "").trim()
        return content ? content.split("\n").filter(row => row.trim()).length : 0
    }
    function refresh() {
        if (!repoProcess.running) repoProcess.running = true
        if (!aurProcess.running) aurProcess.running = true
    }
    Process {
        id: repoProcess; command: ["checkupdates"]
        stdout: StdioCollector { onStreamFinished: root.repoCount = root.countLines(text) }
    }
    Process {
        id: aurProcess; command: ["paru", "-Qua"]
        stdout: StdioCollector { onStreamFinished: root.aurCount = root.countLines(text) }
    }
    Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }
    Component.onCompleted: root.refresh()
}
