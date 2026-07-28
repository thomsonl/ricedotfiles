pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// Owns the org.freedesktop.Notifications bus name, so swaync must not be
// running — only one process can be the notification server at a time.
Singleton {
    id: root

    // Raised for each incoming notification that should surface as a toast.
    // Suppressed entirely while do-not-disturb is on.
    signal notified(var notification)

    property bool dnd: false

    // Notification carries no timestamp of its own, so arrival times are
    // recorded here, keyed by id, to render relative ages in the dropdown.
    property var times: ({})

    // Ticks so the "2m" style labels re-render without needing a signal from
    // the notification itself.
    property double now: Date.now()

    // trackedNotifications is oldest-first; the dropdown wants newest at top.
    readonly property var list: {
        const vals = server.trackedNotifications.values;
        var out = [];
        for (var i = vals.length - 1; i >= 0; i--) out.push(vals[i]);
        return out;
    }

    readonly property int count: list.length

    function relTime(n) {
        const t = root.times[n.id];
        if (!t) return "";
        const secs = Math.floor((root.now - t) / 1000);
        if (secs < 60) return "now";
        if (secs < 3600) return Math.floor(secs / 60) + "m";
        if (secs < 86400) return Math.floor(secs / 3600) + "h";
        return Math.floor(secs / 86400) + "d";
    }

    function dismissAll() {
        // Copy first: dismissing mutates the model being iterated.
        const vals = server.trackedNotifications.values.slice();
        for (const n of vals) n.dismiss();
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    NotificationServer {
        id: server

        // Survive a quickshell config hot-reload instead of dropping the list.
        keepOnReload: true

        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        persistenceSupported: true

        onNotification: function (notification) {
            // A notification that is never tracked is discarded the instant
            // this handler returns, so this is what keeps it in the list.
            notification.tracked = true;
            root.times[notification.id] = Date.now();
            root.now = Date.now();

            // transient notifications are explicitly "do not persist" (progress
            // bars and the like), so they toast but are not kept in the list.
            if (!root.dnd) root.notified(notification);
        }
    }
}
