// Kanso Living Landscape — Plasma 6 wallpaper plugin (MIT).
// No windows, commands, network access, or changes to the user's desktop shell.
import QtQuick
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager

WallpaperItem {
    id: root
    clip: true
    readonly property int slideDuration: Math.max(0, Math.min(5000, (typeof configuration.SlideDuration === "number" ? configuration.SlideDuration : 850)))
    property int desktopIndex: 0

    // Global Kanso light scheme is warm paper; Kanso Night is dark teal.
    // Following the KDE palette avoids rewriting or replacing our wallpaper plugin.
    // Manual override remains available if a custom KDE theme is used.
    readonly property string appearance: configuration.AppearanceOverride || "system"
    readonly property bool systemNight: Kirigami.Theme.backgroundColor.r < 0.5
    readonly property real nightOpacity: appearance === "night" ? 1 :
                                          appearance === "day" ? 0 :
                                          (systemNight ? 1 : 0)

    TaskManager.VirtualDesktopInfo { id: desktopsInfo }
    readonly property int desktopCount: Math.max(1, desktopsInfo.numberOfDesktops || 1)

    function refreshDesktop() {
        const id = desktopsInfo.currentDesktop;
        const ids = desktopsInfo.desktopIds;
        if (id === undefined || id === null || !ids || ids.length === 0) {
            desktopIndex = 0;
            return;
        }
        for (let i = 0; i < ids.length; ++i) {
            // Both values can be QVariant wrappers on Plasma 6.
            if (ids[i] == id) {
                desktopIndex = i;
                return;
            }
        }
        desktopIndex = 0;
    }

    Connections {
        target: desktopsInfo
        function onCurrentDesktopChanged() { root.refreshDesktop(); }
        function onDesktopIdsChanged() { root.refreshDesktop(); }
        function onNumberOfDesktopsChanged() { root.refreshDesktop(); }
    }
    Component.onCompleted: refreshDesktop()
    Timer { interval: 250; repeat: false; running: true; onTriggered: root.refreshDesktop() }

    Rectangle { anchors.fill: parent; color: "#f9eccb" }

    Image {
        id: panorama
        source: Qt.resolvedUrl("../images/kanso-panorama.png")
        asynchronous: true
        cache: true
        smooth: true
        fillMode: Image.Stretch
        // The artwork is 3:1. Cover the screen without distorting it.
        readonly property real aspect: 3.0
        width: Math.max(root.width, root.height * aspect)
        height: width / aspect
        y: (root.height - height) / 2
        readonly property real progress: Math.min(1, Math.max(0, root.desktopIndex / Math.max(1, root.desktopCount - 1)))
        x: -(Math.max(0, width - root.width)) * progress
        Behavior on x {
            NumberAnimation {
                duration: root.slideDuration
                easing.type: Easing.InOutCubic
            }
        }
        // The night illustration has IDENTICAL geometry; it shares the SAME x
        // coordinate and the SAME single SlideDuration animation as daytime.
        // Night changes only opacity. No particles, timers, Canvas or GPU shaders.
        Image {
            id: nightImage
            anchors.fill: parent
            source: Qt.resolvedUrl("../images/kanso-panorama-night.png")
            fillMode: Image.Stretch
            asynchronous: true
            cache: true
            smooth: true
            opacity: root.nightOpacity
            Behavior on opacity {
                NumberAnimation { duration: 1100; easing.type: Easing.InOutQuad }
            }
            onStatusChanged: {
                if (status === Image.Error) console.warn("Kanso: night artwork not found")
            }
        }
        onStatusChanged: {
            if (status === Image.Ready || status === Image.Error || status === Image.Null) {
                root.loading = false
                if (status === Image.Error) console.warn("Kanso: panorama image could not be loaded")
            } else if (status === Image.Loading) {
                root.loading = true
            }
        }
    }

}
