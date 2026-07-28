import QtQuick
import Quickshell.Io

// CPU/RAM/GPU usage, polled every 2s. CPU is a delta over /proc/stat (a single
// snapshot is meaningless — it's cumulative jiffies since boot). RAM comes from
// /proc/meminfo's MemAvailable (accounts for reclaimable cache, unlike MemFree).
// GPU reads amdgpu's own busy-percent counter directly from sysfs for the
// discrete card (card1 = the Radeon RX 9060 XT; card0 is the Raphael iGPU) —
// no external tool needed since the kernel driver already exposes this.
Row {
    id: root

    spacing: 10
    height: 26

    property real cpuPercent: 0
    property real ramPercent: 0
    property real gpuPercent: 0

    property real _prevCpuIdle: 0
    property real _prevCpuTotal: 0
    property bool _cpuPrimed: false

    FileView { id: cpuStatFile; path: "/proc/stat" }
    FileView { id: memInfoFile; path: "/proc/meminfo" }
    FileView { id: gpuBusyFile; path: "/sys/class/drm/card1/device/gpu_busy_percent" }

    readonly property string cpuRaw: cpuStatFile.text()
    readonly property string memRaw: memInfoFile.text()
    readonly property string gpuRaw: gpuBusyFile.text()

    onCpuRawChanged: {
        const line = cpuRaw.split("\n")[0]
        const parts = line.trim().split(/\s+/).slice(1).map(Number)
        if (parts.length < 5) return
        const idle = parts[3] + parts[4]
        const total = parts.reduce((a, b) => a + b, 0)
        if (root._cpuPrimed) {
            const idleDelta = idle - root._prevCpuIdle
            const totalDelta = total - root._prevCpuTotal
            if (totalDelta > 0)
                root.cpuPercent = Math.max(0, Math.min(100, 100 * (1 - idleDelta / totalDelta)))
        }
        root._prevCpuIdle = idle
        root._prevCpuTotal = total
        root._cpuPrimed = true
    }

    onMemRawChanged: {
        const lines = memRaw.split("\n")
        let total = 0, avail = 0
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("MemTotal:") === 0) total = parseFloat(lines[i].replace(/[^0-9]/g, ""))
            else if (lines[i].indexOf("MemAvailable:") === 0) avail = parseFloat(lines[i].replace(/[^0-9]/g, ""))
        }
        if (total > 0) root.ramPercent = Math.max(0, Math.min(100, 100 * (1 - avail / total)))
    }

    onGpuRawChanged: {
        const v = parseFloat(gpuRaw)
        if (!isNaN(v)) root.gpuPercent = Math.max(0, Math.min(100, v))
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuStatFile.reload()
            memInfoFile.reload()
            gpuBusyFile.reload()
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CPU"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.textDim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.cpuPercent) + "%"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.text
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "RAM"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.textDim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.ramPercent) + "%"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.text
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "GPU"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.textDim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round(root.gpuPercent) + "%"
            font.family: Theme.uiFont
            font.pixelSize: 11
            color: Theme.text
        }
    }
}
