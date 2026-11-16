import QtQuick
import Quickshell
import Quickshell.Bluetooth

Scope {
    id: root
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property var devices: available ? adapter.devices.values : []
    readonly property int connectedCount: devices.filter(d => d.connected).length
    function toggle() { if (available) adapter.enabled = !adapter.enabled }
    function discover() { if (available && adapter.enabled) adapter.discovering = true }
    function toggleDevice(device) {
        if (!available || !device) return
        if (device.connected) device.disconnect()
        else device.connect()
    }
}
