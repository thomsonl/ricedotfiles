import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared dropdown for bar modules.
//
// Uses a full-screen overlay rather than a PopupWindow: HyprlandFocusGrab did not
// reliably fire, whereas a fill MouseArea that closes (with the card absorbing its
// own clicks) dismisses correctly every time.
//
// The layer already sits below the bar's exclusive zone, so the card only needs a
// small top margin — adding the bar height here would double-count it.
//
// KNOWN ISSUE (2026-07-28): re-clicking the triggering icon while a dropdown is
// open often doesn't close it -- only Escape or a click elsewhere reliably does.
// Tried and confirmed NOT the fix: hyprctl-dispatched cursor warps, a fresh
// catcher surface positioned over the icon, and real ydotool-injected motion
// (even a large one, injected right before the failing click). See
// project_hyprland_rice_cleanup memory for the full investigation before
// re-attempting any of those. Escape is the reliable workaround for now.
PanelWindow {
    id: popup

    visible: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Screen x of the triggering module's centre; the card is centred on it and
    // clamped so it can never hang off the edge of the display.
    property real anchorCenterX: 0
    property int cardWidth: 280
    property int cardHeight: 200

    default property alias content: holder.data

    function open() { visible = true }
    function close() { visible = false }
    function toggle() { visible ? close() : open() }

    // hoverEnabled gives correct cursor-shape feedback (arrow vs pointer) on
    // this surface; unrelated to the reclick-to-close issue above.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: popup.close()
    }

    Item {
        focus: true
        Keys.onEscapePressed: popup.close()
    }

    Rectangle {
        id: card
        width: popup.cardWidth
        height: popup.cardHeight
        y: 6
        x: Math.max(8, Math.min(parent.width - width - 8,
                                popup.anchorCenterX - width / 2))
        radius: 8
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        // Absorb clicks so they don't reach the dismissing MouseArea behind.
        MouseArea { anchors.fill: parent }

        Item {
            id: holder
            anchors.fill: parent
            anchors.margins: 10
        }
    }
}
