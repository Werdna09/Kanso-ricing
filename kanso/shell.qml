//@ pragma ShellId kanso
import QtQuick
import Quickshell
import Quickshell.Io
import "services"
import "components"

ShellRoot {
    QtObject {
        id: palette
        property string mode: "day"
        readonly property var colors: mode === "night" ? ({
            paper: "#152C34", background: "#142C33", card: "#203943", cardBorder: "#587078", statusOn: "#A9D7BF", statusOff: "#B8A19A", surface: "#23434C",
            surfaceAlt: "#2B535C", border: "#567278", accent: "#D3C7AA",
            text: "#F0E3CB", ink: "#F0E1C3", muted: "#ADC2BC",
            subtleInk: "#B5C6C2", danger: "#E7A696", hover: "#294954"
        }) : ({
            paper: "#FDECC7", background: "#1D3D46", card: "#F6EBD3", cardBorder: "#84928A", statusOn: "#287A65", statusOff: "#997D74", surface: "#294E57",
            surfaceAlt: "#345C65", border: "#6D8D8D", accent: "#B8C5AD",
            text: "#F7E9C9", ink: "#1D414A", muted: "#9EBCB8",
            subtleInk: "#5A777A", danger: "#E0A48F", hover: "#E8D8B7"
        })
        function syncSystem() {
            Quickshell.execDetached([Quickshell.shellDir + "/native/bin/kanso-native", "theme", "--apply", mode])
        }
        property bool autoMode: false
        function desiredMode() {
            const hour = new Date().getHours()
            return hour >= 7 && hour < 19 ? "day" : "night"
        }
        function setMode(selected) {
            if (mode === selected) return
            mode = selected
            themeState.adapter.selected = mode
            themeState.writeAdapter()
            syncSystem()
        }
        function toggleMode() {
            autoMode = false
            themeState.adapter.automatic = false
            setMode(mode === "night" ? "day" : "night")
            themeState.writeAdapter()
        }
        function toggleAutomatic() {
            autoMode = !autoMode
            themeState.adapter.automatic = autoMode
            if (autoMode) setMode(desiredMode())
            themeState.writeAdapter()
        }
        property Timer autoTimer: Timer {
            interval: 60000; running: true; repeat: true
            onTriggered: { if (palette.autoMode) palette.setMode(palette.desiredMode()) }
        }
        property FileView themeState: FileView {
            path: Quickshell.shellDir + "/theme-selection.json"
            blockLoading: true
            adapter: JsonAdapter { property string selected: "day"; property bool automatic: false }
            onLoaded: {
                palette.autoMode = adapter.automatic === true
                palette.mode = palette.autoMode ? palette.desiredMode() :
                              (adapter.selected === "night" ? "night" : "day")
                if (palette.autoMode) {
                    adapter.selected = palette.mode
                    writeAdapter()
                }
                palette.syncSystem()
            }
        }
    }
    KWinWorkspaces {id:workspaces}
    WindowStatus {id:windows}
    AudioStatus {id:audio}
    NetworkStatus {id:network}
    BluetoothStatus {id:bluetooth}
    BatteryStatus {id:battery}
    BrightnessStatus {id:brightness}
    MediaStatus {id:media}
    KeyboardStatus {id:keyboard}
    UpdateStatus {id:updates}
    SystemStatus {id:stats}
    NotificationsStatus {id:notifications}
    KansoPanel {
        palette:palette;workspaces:workspaces;audio:audio;network:network;
        bluetooth:bluetooth;battery:battery;brightness:brightness;media:media;
        keyboard:keyboard;updates:updates;stats:stats;notifications:notifications
    }
    KansoDock {palette:palette;windowService:windows}
    KansoToast {palette:palette;notifications:notifications}
}
