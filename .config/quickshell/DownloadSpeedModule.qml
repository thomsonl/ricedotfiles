import QtQuick
import Quickshell.Io

// Incoming (download) network speed, polled every 1s from /proc/net/dev.
// Sums rx bytes across all non-loopback interfaces rather than picking one —
// only the active interface ever has a growing counter, so this works
// regardless of whether wired or wifi is carrying traffic.
Row {
    id: root

    spacing: 4
    height: 26

    property real bytesPerSec: 0
    property real _prevRxBytes: -1

    FileView { id: netDevFile; path: "/proc/net/dev" }

    readonly property string netDevRaw: netDevFile.text()

    onNetDevRawChanged: {
        const lines = netDevRaw.split("\n").slice(2)
        let totalRx = 0
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line) continue
            const colonIdx = line.indexOf(":")
            if (colonIdx < 0) continue
            const iface = line.slice(0, colonIdx).trim()
            if (iface === "lo") continue
            const fields = line.slice(colonIdx + 1).trim().split(/\s+/)
            totalRx += Number(fields[0])
        }
        if (root._prevRxBytes >= 0)
            root.bytesPerSec = Math.max(0, totalRx - root._prevRxBytes)
        root._prevRxBytes = totalRx
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: netDevFile.reload()
    }

    function formatSpeed(bps) {
        if (bps >= 1024 * 1024) return (bps / (1024 * 1024)).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s"
        return Math.round(bps) + " B/s"
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "↓"
        font.family: Theme.uiFont
        font.pixelSize: 12
        color: Theme.textDim
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.formatSpeed(root.bytesPerSec)
        font.family: Theme.uiFont
        font.pixelSize: 11
        color: Theme.text
    }
}
