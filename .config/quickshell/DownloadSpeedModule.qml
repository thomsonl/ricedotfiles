import QtQuick
import Quickshell.Io

// Incoming (download) network speed, polled every 1s from /proc/net/dev.
// Sums rx bytes across all non-loopback interfaces rather than picking one —
// only the active interface ever has a growing counter, so this works
// regardless of whether wired or wifi is carrying traffic.
Item {
    id: root

    // Fixed so the pill never resizes as the speed value bounces around: the
    // arrow and number stay a tightly-packed, centred unit (see the Row
    // below), so a shorter reading just re-centres instead of shifting the
    // arrow or leaving a gap between it and the number.
    implicitWidth: arrowMetrics.advanceWidth("↓") + 4 + speedMetrics.advanceWidth("999 GB/s")
    implicitHeight: 26

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

    // KB/MB/GB only (no bytes/s). Two significant digits at all times: once
    // the whole-number reading would drop to a single digit (0-9), switch to
    // one decimal place (e.g. "3.4") instead; from 10 up it's a plain whole
    // number, so it never exceeds 3 characters (0-999) before rolling over
    // to the next unit.
    function formatSpeed(bps) {
        let raw, unit
        if (bps >= 1000 * 1000 * 1000) { raw = bps / (1000 * 1000 * 1000); unit = "GB/s" }
        else if (bps >= 1000 * 1000) { raw = bps / (1000 * 1000); unit = "MB/s" }
        else { raw = bps / 1000; unit = "KB/s" }
        const text = raw < 9.95 ? raw.toFixed(1) : String(Math.round(raw))
        return text + " " + unit
    }

    FontMetrics {
        id: arrowMetrics
        font.family: Theme.uiFont
        font.pixelSize: 12
    }

    FontMetrics {
        id: speedMetrics
        font.family: Theme.uiFont
        font.pixelSize: 11
    }

    Row {
        anchors.centerIn: parent
        spacing: 4

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
}
