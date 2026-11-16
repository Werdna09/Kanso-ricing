import QtQuick

Rectangle {
    id: root
    required property var palette
    property string title: ""
    property string detail: ""
    property bool selected: false
    property bool danger: false
    signal invoked()
    implicitHeight: detail.length ? 46 : 34
    radius: 7
    color: (root.enabled && hit.containsMouse) || selected ? palette.colors.surfaceAlt : palette.colors.surface
    border.width: selected ? 1 : 0
    border.color: palette.colors.accent
    Column {
        anchors { left: parent.left; right: parent.right; leftMargin: 12; rightMargin: 12; verticalCenter: parent.verticalCenter }
        spacing: 3
        Text { text: root.title; width: parent.width; elide: Text.ElideRight
            font.family: "Noto Sans"; font.pixelSize: 12
            color: root.danger ? root.palette.colors.danger : root.palette.colors.text }
        Text { visible: root.detail.length > 0; text: root.detail; width: parent.width
            elide: Text.ElideRight; font.family: "Noto Sans"; font.pixelSize: 10
            color: root.palette.colors.muted }
    }
    MouseArea { id: hit; anchors.fill: parent; hoverEnabled: true
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.invoked() }
}
