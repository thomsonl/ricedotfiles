import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

// Replaces swaync's popups. Sized to its content rather than filling the
// screen, so clicks anywhere else fall straight through to the desktop.
PanelWindow {
    id: toasts

    property int toastWidth: 360
    property int defaultTimeout: 5000

    // Entries are { id, n, expiry }. A plain array plus one pruning timer is
    // simpler than a timer per toast and avoids holding destroyed objects.
    property var entries: []

    visible: entries.length > 0
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    // Reserve no space of its own. Ignore also means this window does not get
    // pushed below the bar's exclusive zone, so the top margin has to clear the
    // bar by hand — unlike BarPopup, which is positioned for it automatically.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        right: true
    }

    // barHeight (34) + a small gap.
    margins {
        top: 40
        right: 8
    }

    implicitWidth: toastWidth + 16
    implicitHeight: Math.max(1, column.implicitHeight + 12)

    function push(n) {
        // Critical notifications stay until acted on; everything else follows
        // the sender's requested timeout, falling back to a sane default.
        var ms = toasts.defaultTimeout;
        if (n.urgency === NotificationUrgency.Critical) ms = 0;
        else if (n.expireTimeout > 0) ms = n.expireTimeout;

        var next = toasts.entries.slice();
        next.push({
            id: n.id,
            n: n,
            expiry: ms > 0 ? Date.now() + ms : 0
        });
        toasts.entries = next;
    }

    function removeId(id) {
        var next = [];
        for (const e of toasts.entries) {
            if (e.id !== id) next.push(e);
        }
        toasts.entries = next;
    }

    Connections {
        target: NotificationService
        function onNotified(notification) {
            toasts.push(notification);
        }
    }

    Timer {
        interval: 250
        running: toasts.entries.length > 0
        repeat: true
        onTriggered: {
            const now = Date.now();
            var next = [];
            for (const e of toasts.entries) {
                if (e.expiry === 0 || e.expiry > now) next.push(e);
            }
            if (next.length !== toasts.entries.length) toasts.entries = next;
        }
    }

    Column {
        id: column
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: toasts.toastWidth
        spacing: 6

        Repeater {
            model: toasts.entries

            delegate: NotificationCard {
                id: toast

                required property var modelData

                width: parent.width
                notification: modelData.n
                standalone: true

                onDismissed: {
                    toasts.removeId(modelData.id);
                    modelData.n.dismiss();
                }

                // If the notification is closed from anywhere else (the
                // dropdown's Clear, or the sending app), drop the toast too
                // rather than leaving it pointing at a dead object.
                Connections {
                    target: toast.notification
                    function onClosed() {
                        toasts.removeId(toast.modelData.id);
                    }
                }

                // Clicking the body dismisses, matching the popup behaviour
                // people expect from swaync.
                MouseArea {
                    anchors.fill: parent
                    z: -1
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        toasts.removeId(toast.modelData.id);
                        toast.notification.dismiss();
                    }
                }

                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
