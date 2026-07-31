import QtQuick

// A ListView tuned for small bar dropdowns:
//
// - Wheel/trackpad input moves contentY directly with no inertia or
//   deceleration animation, and by a bigger step per notch than Flickable's
//   tiny default, so a 6-row list doesn't feel sluggish to scroll.
//
// - Scroll offset survives data refreshes. Both the wifi and notification
//   lists rebuild their source as a brand-new array on every underlying
//   data change (periodic wifi rescans, new/dismissed notifications),
//   often with identical or near-identical content. Callers bind to
//   `source` (not `model` directly): _restoreY is only ever updated by the
//   wheel handler below, i.e. by actual user scrolling -- never by the
//   contentY==0 that Qt itself produces when `model` gets reassigned to a
//   new array. That means a refresh can freely reset contentY and we just
//   put it back where the user last left it, instead of racing to
//   distinguish "reset" from "scroll" after the fact.
//
// Deliberately NOT using a persistent ListModel patched in place here --
// that was tried and caused duplicate/empty rows across repeated
// open/close cycles (delegate reuse + row patching turned out fragile).
// Plain array-model reassignment is the well-trodden Qt path; restoring
// contentY after the fact is a much smaller surface for bugs.
ListView {
    id: list

    clip: true
    boundsBehavior: Flickable.StopAtBounds

    // Wheel step size: notchRows rows per 120 angle-delta units (one
    // physical notch on a mouse wheel).
    property real rowHeight: 34
    property real notchRows: 1

    property var source
    property real _restoreY: -1

    function _clampY(y) {
        return Math.max(0, Math.min(y, Math.max(0, contentHeight - height)))
    }

    // Skip the reassignment (and the reset it causes) entirely when the
    // refresh didn't actually change anything.
    function _sameSource(a, b) {
        if (a === b) return true
        if (!a || !b || a.length !== b.length) return false
        for (var i = 0; i < a.length; i++) {
            if (a[i] !== b[i]) return false
        }
        return true
    }

    onSourceChanged: {
        if (_sameSource(source, model)) return
        model = source
        Qt.callLater(function () {
            if (list._restoreY >= 0) list.contentY = list._clampY(list._restoreY)
        })
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const delta = event.angleDelta.y / 120 * list.rowHeight * list.notchRows
            list.contentY = list._clampY(list.contentY - delta)
            list._restoreY = list.contentY
        }
    }
}
