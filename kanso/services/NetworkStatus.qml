import QtQuick
import Quickshell
import Quickshell.Networking

Scope {
    id: root
    readonly property var wifiDevice: {
        for (const dev of Networking.devices.values) if (dev.type === DeviceType.Wifi) return dev
        return null
    }
    readonly property var networks: wifiDevice !== null ? wifiDevice.networks.values : []
    readonly property var currentWifi: {
        for (const wifi of networks) if (wifi.connected) return wifi
        return null
    }
    readonly property bool wifiAvailable: wifiDevice !== null && Networking.wifiHardwareEnabled
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiConnected: currentWifi !== null
    readonly property string wifiName: currentWifi !== null ? currentWifi.name : ""
    function toggleWifi() { if (wifiAvailable) Networking.wifiEnabled = !Networking.wifiEnabled }
    function scan() { if (wifiDevice !== null) wifiDevice.scannerEnabled = true }
    function connectKnown(net) { if (net && net.known) net.connect() }
    Component.onCompleted: scan()
}
