import QtQuick

Item {
    id: root
    required property var palette
    property int value: 0
    signal changed(int value)
    implicitHeight: 28
    Rectangle {
        id: rail; width: parent.width; height: 8; radius: 4
        anchors.verticalCenter: parent.verticalCenter
        color: root.palette.colors.surfaceAlt
        Rectangle { height: parent.height; radius: parent.radius
            width: Math.max(0, parent.width * Math.min(100, Math.max(0, root.value)) / 100)
            color: root.palette.colors.accent }
        MouseArea { anchors.fill: parent; anchors.topMargin: -12; anchors.bottomMargin: -12
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => root.changed(Math.round(100 * mouse.x / width))
            onPositionChanged: mouse => { if (pressed) root.changed(Math.round(100 * mouse.x / width)) } }
    }
}
