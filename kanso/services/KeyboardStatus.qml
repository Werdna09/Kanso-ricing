import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property int currentIndex: 0
    readonly property string label: currentIndex === 0 ? "CZ" : "EN"
    property bool capsLock: false
    property bool numLock: false
    property bool capsAvailable: false
    property bool numAvailable: false
    readonly property string displayLabel: label + (numLock ? " N" : "") + (capsLock ? " C" : "")
    function refreshLocks() { if (!lockQuery.running) lockQuery.running = true }
    Process {
        id: lockQuery
        command: [Quickshell.shellDir + "/native/bin/kanso-native", "locks"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text.trim())
                    root.capsAvailable = v.caps !== null
                    root.numAvailable = v.num !== null
                    root.capsLock = v.caps === true
                    root.numLock = v.num === true
                } catch (e) { console.warn("Kanso: failed to read keyboard locks:", e) }
            }
        }
    }
    Timer { interval: 1700; repeat: true; running: true; onTriggered: root.refreshLocks() }
    function refreshLayout() { if (!query.running) query.running = true }
    function nextLayout() {
        Quickshell.execDetached(["qdbus6", "org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts.switchToNextLayout"])
        refreshDelay.restart()
    }
    Process {
        id: query
        command: ["qdbus6", "org.kde.keyboard", "/Layouts", "org.kde.KeyboardLayouts.getLayout"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim())
                if (!isNaN(n) && n >= 0) root.currentIndex = n
            }
        }
    }
    Timer { id: refreshDelay; interval: 350; repeat: false; onTriggered: root.refreshLayout() }
    Timer { interval: 3000; repeat: true; running: true; onTriggered: root.refreshLayout() }
    Component.onCompleted: { root.refreshLayout(); root.refreshLocks() }
}
