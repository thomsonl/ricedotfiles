import QtQuick

// Minimal draggable slider: click/drag anywhere on the track to set value.
// `moved` fires continuously while dragging (for live previews), `released`
// fires once on mouse-up with the final value (for actions that shouldn't
// spam their backend, e.g. seeking).
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    property bool enabled: true

    signal moved(real value)
    signal released(real value)

    implicitHeight: 14

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function ratioToValue(r) {
        return from + Math.max(0, Math.min(1, r)) * (to - from)
    }

    opacity: enabled ? 1 : 0.4

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Theme.textFaint
    }

    Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        width: track.width * root.ratio
        color: Theme.accent
    }

    Rectangle {
        width: 10
        height: 10
        radius: 5
        color: Theme.text
        anchors.verticalCenter: parent.verticalCenter
        x: track.width * root.ratio - width / 2
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor

        function updateFromX(px) {
            root.value = root.ratioToValue(px / root.width)
            root.moved(root.value)
        }

        onPressed: (ev) => updateFromX(ev.x)
        onPositionChanged: (ev) => { if (pressed) updateFromX(ev.x) }
        onReleased: () => root.released(root.value)
    }
}
