import QtQuick
import Quickshell
import Quickshell.Io

// CPU/GPU/RAM usage, polled every 2s. CPU is a delta over /proc/stat (a single
// snapshot is meaningless — it's cumulative jiffies since boot). RAM comes from
// /proc/meminfo's MemAvailable (accounts for reclaimable cache, unlike MemFree).
// GPU reads amdgpu's own busy-percent counter directly from sysfs for the
// discrete card (card1 = the Radeon RX 9060 XT; card0 is the Raphael iGPU) —
// no external tool needed since the kernel driver already exposes this.
//
// Clicking the bubble opens a dropdown with CPU/GPU temps and RAM's GB
// breakdown (RAM has no temp sensor, so it gets used/total GB instead).
// Temps: CPU is k10temp's Tctl (hwmon3); GPU is amdgpu's edge sensor under
// card1's own hwmon (hwmon1). Both hwmon indices are probe-order assigned
// and could shift after a kernel/driver update — if a temp reads 0 or goes
// stale, check `cat /sys/class/hwmon/hwmon*/name` for the new index.
Item {
    id: root

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    property real cpuPercent: 0
    property real gpuPercent: 0
    property real ramPercent: 0

    property real cpuTempC: 0
    property real gpuTempC: 0

    property real ramUsedGB: 0
    property real ramTotalGB: 0

    // Tracked explicitly rather than read off mouse.containsMouse directly:
    // once the dropdown's full-screen overlay appears on top, Hyprland sends
    // this surface a pointer-leave (focus moved to the overlay) even though
    // the cursor never actually moved, which would otherwise blink the
    // highlight off for the whole time the dropdown is open. OR-ing in
    // panel.visible below keeps it lit through that -- true hover state is
    // still tracked here underneath and takes back over the instant the
    // popup closes.
    property bool hovered: false

    // Guards against the bar's documented re-click-doesn't-close quirk: the
    // popup's full-screen dismiss overlay appears on top mid-click, so the
    // same physical click's press/release can end up split across two
    // surfaces -- the release lands back on this MouseArea once the overlay
    // is gone and fires a second, unintended toggle that instantly reopens
    // what the overlay's own click just closed. Locking this handler out for
    // a few ms after every click swallows that stray follow-up without
    // affecting real clicks (nobody double-clicks that fast).
    property bool _clickLocked: false

    property real _prevCpuIdle: 0
    property real _prevCpuTotal: 0
    property bool _cpuPrimed: false

    FileView { id: cpuStatFile; path: "/proc/stat" }
    FileView { id: memInfoFile; path: "/proc/meminfo" }
    FileView { id: gpuBusyFile; path: "/sys/class/drm/card1/device/gpu_busy_percent" }
    FileView { id: cpuTempFile; path: "/sys/class/hwmon/hwmon3/temp1_input" }
    FileView { id: gpuTempFile; path: "/sys/class/drm/card1/device/hwmon/hwmon1/temp1_input" }

    readonly property string cpuRaw: cpuStatFile.text()
    readonly property string memRaw: memInfoFile.text()
    readonly property string gpuRaw: gpuBusyFile.text()
    readonly property string cpuTempRaw: cpuTempFile.text()
    readonly property string gpuTempRaw: gpuTempFile.text()

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
        if (total > 0) {
            root.ramPercent = Math.max(0, Math.min(100, 100 * (1 - avail / total)))
            // MemTotal/MemAvailable are in KiB.
            root.ramTotalGB = total / (1024 * 1024)
            root.ramUsedGB = (total - avail) / (1024 * 1024)
        }
    }

    onGpuRawChanged: {
        const v = parseFloat(gpuRaw)
        if (!isNaN(v)) root.gpuPercent = Math.max(0, Math.min(100, v))
    }

    onCpuTempRawChanged: {
        const v = parseFloat(cpuTempRaw)
        if (!isNaN(v)) root.cpuTempC = v / 1000
    }

    onGpuTempRawChanged: {
        const v = parseFloat(gpuTempRaw)
        if (!isNaN(v)) root.gpuTempC = v / 1000
    }

    // Polls every 2s normally; while the dropdown is open, every 1s so the
    // temps/usage it's showing stay live instead of sitting on a stale read.
    Timer {
        id: pollTimer
        interval: panel.visible ? 1000 : 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuStatFile.reload()
            memInfoFile.reload()
            gpuBusyFile.reload()
            cpuTempFile.reload()
            gpuTempFile.reload()
        }
    }

    Timer {
        id: clickLockTimer
        interval: 10
        onTriggered: root._clickLocked = false
    }

    // Each percent reading gets a fixed width sized for its widest possible
    // case ("100%") so the pill never resizes as CPU/GPU/RAM bounce between
    // 2% and 100% -- a shorter reading just leaves trailing space instead of
    // shifting the next stat group over.
    FontMetrics {
        id: percentMetrics
        font.family: Theme.uiFont
        font.pixelSize: 11
    }

    // Closing the popup via a click on this same pill still produces a brief
    // flicker: the overlay's own close() fires first (wantHighlight instantly
    // false, since panel.visible just dropped and the earlier overlay-stealing
    // exited already zeroed hovered), and only a beat later does the freshly-
    // unmapped overlay hand hover back to this MouseArea and set hovered true
    // again. Debouncing the *off* transition (never the *on* one) swallows that
    // gap without adding any perceptible delay to real mouse-leaves.
    readonly property bool wantHighlight: hovered || panel.visible
    property bool highlightOn: false
    onWantHighlightChanged: {
        if (wantHighlight) {
            highlightOffTimer.stop()
            highlightOn = true
        } else {
            highlightOffTimer.restart()
        }
    }

    Timer {
        id: highlightOffTimer
        interval: 80
        onTriggered: root.highlightOn = false
    }

    // Sized to match the outer pill drawn in shell.qml (statsModule.implicitWidth
    // + 12), which root itself is centred inside of -- filling just root's own
    // bounds left the highlight visibly inset from the pill's actual edges.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width + 12
        height: parent.height
        radius: 8
        color: root.highlightOn ? Theme.hover : "transparent"
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CPU"
                font.family: Theme.uiFont
                font.pixelSize: 11
                color: Theme.textDim
            }
            // 2px on both sides: right-anchored with a 2px margin keeps the
            // gap before the next label fixed at 2px regardless of digit
            // count; the box being 4px wider than the "100%" case guarantees
            // at least 2px on the left too (more, once the value is short
            // enough to not reach that far).
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: percentMetrics.advanceWidth("100%") + 4
                height: cpuValueText.implicitHeight

                Text {
                    id: cpuValueText
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.cpuPercent) + "%"
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    color: Theme.text
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "GPU"
                font.family: Theme.uiFont
                font.pixelSize: 11
                color: Theme.textDim
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: percentMetrics.advanceWidth("100%") + 4
                height: gpuValueText.implicitHeight

                Text {
                    id: gpuValueText
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.gpuPercent) + "%"
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    color: Theme.text
                }
            }
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "RAM"
                font.family: Theme.uiFont
                font.pixelSize: 11
                color: Theme.textDim
            }
            // RAM is last, so it keeps flush against the pill's right edge:
            // padding only on the left (box is 2px wider than "100%", no
            // right margin on the text).
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: percentMetrics.advanceWidth("100%") + 2
                height: ramValueText.implicitHeight

                Text {
                    id: ramValueText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.ramPercent) + "%"
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    color: Theme.text
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.centerIn: parent
        width: parent.width + 12
        height: parent.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: {
            if (root._clickLocked) return
            root._clickLocked = true
            clickLockTimer.restart()
            panel.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x
            panel.toggle()
        }
    }

    BarPopup {
        id: panel
        // The one-line text is wider than the trigger pill itself, so the
        // card follows the text's own width (plus the holder's 10px margin
        // on each side) rather than the pill's -- otherwise it would have
        // to wrap or clip. Still far more compact than the other dropdowns.
        cardWidth: statsText.implicitWidth + 20
        cardHeight: 30
        cardColor: "#b31e1e2e"

        // Jump to the 1s cadence (and grab a fresh read right away) the
        // moment it opens, rather than waiting up to 2s on a stale value.
        onVisibleChanged: if (visible) pollTimer.restart()

        Text {
            id: statsText
            anchors.centerIn: parent
            text: "CPU: " + Math.round(root.cpuTempC) + "°C    GPU: " + Math.round(root.gpuTempC) + "°C    RAM: " + root.ramUsedGB.toFixed(1) + "/" + root.ramTotalGB.toFixed(0) + "GB"
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }
}
