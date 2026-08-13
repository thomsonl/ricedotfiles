import QtQuick
import Quickshell
import Quickshell.Wayland

// Shared dropdown for bar modules.
//
// Uses a full-screen overlay rather than a PopupWindow: HyprlandFocusGrab did not
// reliably fire, whereas a fill MouseArea that closes (with the card absorbing its
// own clicks) dismisses correctly every time.
//
// FIXED (2026-08-13): without ExclusionMode.Ignore, this layer was auto-pushed
// below the bar's exclusive zone (confirmed via `hyprctl layers`: it only spanned
// y=34..1080, not 0..1080), so the dismiss MouseArea never covered the bar strip
// itself -- clicking anywhere on the bar, including re-clicking the triggering
// icon, silently did nothing because the click never reached this window at all.
// (What looked like the icon-reclick "not closing" in earlier testing was this,
// not a separate bug -- confirmed via `hyprctl layers` that close() does fire,
// screenshots taken immediately after just raced the compositor's repaint.)
// Ignore stops that push-down (matching NotificationToasts.qml's already-established
// use of the same flag), so the card's own offset has to clear the bar by hand now.
PanelWindow {
    id: popup

    visible: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // barHeight (34) + a small gap -- see the card's y below.
    property int barHeight: 34

    // Screen x of the triggering module's centre; the card is centred on it and
    // clamped so it can never hang off the edge of the display.
    property real anchorCenterX: 0
    property int cardWidth: 280
    property int cardHeight: 200
    property color cardColor: Theme.surface

    default property alias content: holder.data

    function open() { PopupManager.requestOpen(popup); visible = true }
    function close() { visible = false; PopupManager.notifyClosed(popup) }
    function toggle() { visible ? close() : open() }

    // Pointing-hand cursor here too: once this overlay is up, it's what's
    // actually under the pointer (even over the triggering icon, now that it
    // spans the whole screen per the Ignore fix above) -- without this, the
    // cursor was falling back to the plain arrow the moment a dropdown opened.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.close()
    }

    Item {
        focus: true
        Keys.onEscapePressed: popup.close()
    }

    // This window only ever renders on the bar's own screen (DP-1), so a click
    // on any other monitor never reaches a quickshell surface at all and the
    // popup stays open until you click back on DP-1 or hit Escape. Give every
    // other screen its own invisible click-catcher, card-free, that just closes
    // this popup.
    Variants {
        model: Quickshell.screens.filter(s => s.name !== "DP-1")

        PanelWindow {
            required property var modelData
            screen: modelData

            visible: popup.visible
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors { top: true; bottom: true; left: true; right: true }

            MouseArea {
                anchors.fill: parent
                onClicked: popup.close()
            }
        }
    }

    Rectangle {
        id: card
        width: popup.cardWidth
        height: popup.cardHeight
        y: popup.barHeight + 6
        x: Math.max(8, Math.min(parent.width - width - 8,
                                popup.anchorCenterX - width / 2))
        radius: 8
        color: popup.cardColor
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
