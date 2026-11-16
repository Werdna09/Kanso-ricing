import QtQuick

// Kanso 3.1: a single unobtrusive floating capsule. Hover and active states are subtle,
// actual connection/power states are displayed without disabling interaction.
Rectangle {
    id: root
    required property var palette
    property string icon: ""
    property string label: ""
    property int iconSize: 21
    property int buttonWidth: 42
    property bool selected: false
    property bool emphasized: false
    property bool activeState: false
    property bool inactiveState: false
    property bool showState: false
    signal invoked()
    signal scrolled(int delta)

    implicitWidth: buttonWidth
    implicitHeight: 40
    radius: 9
    color: selected || pointer.containsMouse ? root.palette.colors.hover : root.palette.colors.card
    border.width: 1
    border.color: selected ? root.palette.colors.accent : root.palette.colors.cardBorder

    Row {
        anchors.centerIn: parent
        spacing: 7
        Image {
            visible: root.icon.length > 0
            width: visible ? root.iconSize : 0
            height: root.iconSize
            opacity: root.inactiveState ? 0.48 : 1.0
            source: root.icon.length > 0
                ? Qt.resolvedUrl("../assets/icons/" + root.palette.mode + "/" + root.icon + ".svg") : ""
            sourceSize: Qt.size(2 * root.iconSize, 2 * root.iconSize)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            visible: root.label.length > 0
            width: root.buttonWidth > 145 ? Math.min(195, root.buttonWidth - 40) : implicitWidth
            elide: Text.ElideRight
            text: root.label
            font.family: "Noto Sans"
            font.pixelSize: root.emphasized ? 13 : 12
            font.bold: root.emphasized
            color: root.inactiveState ? root.palette.colors.subtleInk : root.palette.colors.ink
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Rectangle {
        visible: root.showState
        width: 6; height: 6; radius: 3
        anchors { right: parent.right; rightMargin: 3; bottom: parent.bottom; bottomMargin: 4 }
        color: root.activeState ? root.palette.colors.statusOn : root.palette.colors.statusOff
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.invoked()
        onWheel: wheel => {
            root.scrolled(wheel.angleDelta.y)
            wheel.accepted = true
        }
    }
}
