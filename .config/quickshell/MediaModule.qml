import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var player: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying) return list[i]
        }
        return list.length > 0 ? list[0] : null
    }
    readonly property bool active: player !== null

    onActiveChanged: {
        if (!active) panel.close()
        else refresh()
    }
    onPlayerChanged: refresh()

    visible: active
    implicitWidth: active ? content.implicitWidth + 14 : 0
    implicitHeight: 26

    function fmtTime(sec) {
        if (!sec || sec <= 0 || isNaN(sec)) return "0:00"
        const s = Math.floor(sec)
        const m = Math.floor(s / 60)
        const r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }

    // MPRIS only notifies position on seeks/track changes, not every second the
    // track plays, so the visible slider is driven by a poll timer rather than
    // positionChanged alone.
    property bool seeking: false
    property real seekPreview: 0
    property int tick: 0

    function refresh() { tick++ }

    Connections {
        target: root.player
        enabled: root.active
        function onPositionChanged() { root.refresh() }
        function onTrackTitleChanged() { root.refresh() }
    }

    Timer {
        interval: 500
        repeat: true
        running: panel.visible && root.active && root.player.isPlaying && !root.seeking
        onTriggered: root.refresh()
    }

    readonly property real displayPosition: {
        root.tick
        if (root.seeking) return root.seekPreview
        return root.active ? root.player.position : 0
    }

    // Tiny real-time spectrum shown in the bar itself, driven by cava reading
    // the default sink's monitor (see cava.conf: 4 bars, raw ascii, 0-20 range).
    property var barValues: [0, 0, 0, 0]

    Process {
        id: cavaProc
        running: root.active && root.player.isPlaying
        command: ["cava", "-p", "/home/thomson/.config/quickshell/cava.conf"]
        stdout: SplitParser {
            onRead: (line) => {
                const parts = line.split(";").filter(s => s.length > 0).map(Number)
                if (parts.length === root.barValues.length) root.barValues = parts
            }
        }
        onRunningChanged: {
            if (!running) root.barValues = [0, 0, 0, 0]
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Row {
            id: visualizer
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            spacing: 2

            Repeater {
                model: root.barValues

                delegate: Item {
                    required property var modelData

                    width: 3
                    height: 14

                    Rectangle {
                        width: parent.width
                        radius: 1
                        color: Theme.accent
                        anchors.bottom: parent.bottom
                        height: Math.max(2, modelData / 20 * parent.height)

                        Behavior on height {
                            NumberAnimation { duration: 60 }
                        }
                    }
                }
            }
        }

        Item {
            id: trackTextContainer
            anchors.verticalCenter: parent.verticalCenter
            visible: root.active
            clip: true

            readonly property int maxTextWidth: 220
            readonly property bool overflowing: trackText.implicitWidth > maxTextWidth
            readonly property real scrollDistance: trackText.implicitWidth - maxTextWidth

            width: Math.min(trackText.implicitWidth, maxTextWidth)
            height: trackText.implicitHeight

            Text {
                id: trackText
                text: {
                    if (!root.active) return ""
                    const artist = root.player.trackArtist
                    const title = root.player.trackTitle
                    return artist ? artist + " – " + title : title
                }
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 12
                maximumLineCount: 1
                elide: Text.ElideRight
                width: (trackArea.containsMouse && trackTextContainer.overflowing) ? implicitWidth : trackTextContainer.width

                SequentialAnimation {
                    running: trackArea.containsMouse && trackTextContainer.overflowing
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) trackText.x = 0

                    PauseAnimation { duration: 800 }
                    NumberAnimation {
                        target: trackText
                        property: "x"
                        from: 0
                        to: -trackTextContainer.scrollDistance
                        duration: Math.max(1200, trackTextContainer.scrollDistance * 30)
                        easing.type: Easing.InOutQuad
                    }
                    PauseAnimation { duration: 800 }
                    NumberAnimation {
                        target: trackText
                        property: "x"
                        from: -trackTextContainer.scrollDistance
                        to: 0
                        duration: Math.max(1200, trackTextContainer.scrollDistance * 30)
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            MouseArea {
                id: trackArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    panel.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x
                    panel.toggle()
                }
            }
        }
    }

    BarPopup {
        id: panel
        cardWidth: 240
        cardHeight: 210

        Column {
            width: parent.width
            spacing: 12

            Row {
                width: parent.width
                spacing: 10

                Item {
                    id: artContainer
                    width: 56
                    height: 56

                    Image {
                        id: artImage
                        anchors.fill: parent
                        source: root.active && root.player.trackArtUrl ? root.player.trackArtUrl : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: false
                    }

                    Rectangle {
                        id: artMask
                        anchors.fill: parent
                        radius: 8
                        visible: false
                        layer.enabled: true
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: artImage
                        maskEnabled: true
                        maskSource: artMask
                        visible: artImage.status === Image.Ready
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Theme.hover
                        visible: artImage.status !== Image.Ready

                        Text {
                            anchors.centerIn: parent
                            text: "󰝚"
                            font.family: Theme.iconFont
                            font.pixelSize: 22
                            color: Theme.textDim
                        }
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 56 - 10
                    spacing: 2

                    Text {
                        width: parent.width
                        text: root.active ? root.player.trackTitle : ""
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.active ? root.player.trackArtist : ""
                        color: Theme.textDim
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: root.active ? root.player.identity : ""
                        color: Theme.textFaint
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4

                Slider {
                    width: parent.width
                    enabled: root.active && root.player.positionSupported && root.player.canSeek
                    from: 0
                    to: root.active && root.player.length > 0 ? root.player.length : 1
                    value: root.displayPosition
                    onMoved: (v) => { root.seeking = true; root.seekPreview = v }
                    onReleased: (v) => {
                        if (root.active) root.player.position = v
                        root.seeking = false
                    }
                }

                Row {
                    width: parent.width

                    Text {
                        id: posText
                        text: root.fmtTime(root.displayPosition)
                        color: Theme.textDim
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                    }
                    Item { width: parent.width - posText.implicitWidth - lenText.implicitWidth; height: 1 }
                    Text {
                        id: lenText
                        text: root.active ? root.fmtTime(root.player.length) : "0:00"
                        color: Theme.textDim
                        font.family: Theme.uiFont
                        font.pixelSize: 10
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28

                Text {
                    text: "󰒮"
                    color: (root.active && root.player.canGoPrevious) ? (popupPrevArea.containsMouse ? Theme.text : Theme.textDim) : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    MouseArea {
                        id: popupPrevArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.active && root.player.canGoPrevious
                        onClicked: root.player.previous()
                    }
                }

                Text {
                    text: root.active && root.player.isPlaying ? "󰏤" : "󰐊"
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    MouseArea {
                        id: popupPlayArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.active && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                    }
                }

                Text {
                    text: "󰒭"
                    color: (root.active && root.player.canGoNext) ? (popupNextArea.containsMouse ? Theme.text : Theme.textDim) : Theme.textFaint
                    font.family: Theme.iconFont
                    font.pixelSize: 16
                    MouseArea {
                        id: popupNextArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.active && root.player.canGoNext
                        onClicked: root.player.next()
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!root.active) return "󰝟"
                        const v = root.player.volume
                        if (v <= 0.001) return "󰝟"
                        if (v < 0.5) return "󰖀"
                        return "󰕾"
                    }
                    color: Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                }

                Slider {
                    width: parent.width - 22
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: root.active && root.player.volumeSupported
                    from: 0
                    to: 1
                    value: root.active ? root.player.volume : 0
                    onMoved: (v) => { if (root.active) root.player.volume = v }
                }
            }
        }
    }
}
