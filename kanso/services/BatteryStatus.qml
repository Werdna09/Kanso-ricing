import QtQuick
import Quickshell
import Quickshell.Services.UPower

Scope {
    id: root
    readonly property var battery: UPower.displayDevice
    readonly property bool available: battery !== null && battery.ready
    readonly property int percentage: available ? Math.round(battery.percentage * 100) : 0
    readonly property bool charging: available && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
}
