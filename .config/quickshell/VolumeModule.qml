import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var audio: sink ? sink.audio : null
    readonly property real volume: audio ? audio.volume : 0
    readonly property bool muted: audio ? audio.muted : false

    // Real output devices only -- excludes sink-input streams (individual
    // apps' playback streams show up in Pipewire.nodes too).
    readonly property var outputSinks: {
        var out = []
        var all = Pipewire.nodes.values
        for (var i = 0; i < all.length; i++) {
            var n = all[i]
            if (n.isSink && !n.isStream) out.push(n)
        }
        return out
    }

    function cycleSink() {
        var nodes = root.outputSinks
        if (nodes.length < 2) return
        var idx = nodes.indexOf(root.sink)
        Pipewire.preferredDefaultAudioSink = nodes[(idx + 1) % nodes.length]
    }

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    // Without tracking the node, its audio properties never populate/update.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }

    function icon() {
        if (muted || volume <= 0.001) return "󰝟"
        if (volume < 0.34) return "󰕿"
        if (volume < 0.67) return "󰖀"
        return "󰕾"
    }

    function setVolume(v) {
        if (!audio) return
        audio.volume = Math.max(0, Math.min(1, v))
    }

    Process { id: mixer; command: ["pavucontrol"] }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon()
            color: root.muted ? Theme.textDim : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.textDim : Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onClicked: function(ev) {
            if (ev.button === Qt.LeftButton) {
                mixer.running = true
            } else if (ev.button === Qt.MiddleButton) {
                root.cycleSink()
            } else if (root.audio) {
                root.audio.muted = !root.audio.muted
            }
        }

        onWheel: function(ev) {
            root.setVolume(root.volume + (ev.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }
}
