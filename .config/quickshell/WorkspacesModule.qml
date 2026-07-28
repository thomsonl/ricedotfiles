import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    // Which global workspace ids this instance shows, and how much to
    // subtract for display so e.g. the BenQ's [4, 5, 6] still reads "1 2 3".
    required property var workspaceIds
    property int labelOffset: 0

    readonly property var entries: {
        const live = Hyprland.workspaces.values;
        return root.workspaceIds.map(function(id) {
            var match = null;
            for (const ws of live) {
                if (ws.id === id) {
                    match = ws;
                    break;
                }
            }
            return { id: id, ws: match, label: String(id - root.labelOffset) };
        });
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 26

    function focusedIndex() {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].ws && entries[i].ws.focused) return i;
        }
        return -1;
    }

    function switchTo(entry) {
        // A workspace that exists has a real object, and activate() already
        // knows how to talk to both a classic and a Lua Hyprland config.
        if (entry.ws) {
            entry.ws.activate();
            return;
        }

        // An empty workspace has no object yet, so it has to be dispatched by
        // hand. A Lua config evaluates the dispatch argument as Lua, where the
        // classic "workspace N" string is a syntax error, so the form differs.
        if (Hyprland.usingLua) {
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + entry.id + '" })');
        } else {
            Hyprland.dispatch("workspace " + entry.id);
        }
    }

    // Wheel cycles through the entries as displayed, so it steps onto empty
    // workspaces too rather than only hopping between occupied ones.
    function cycle(delta) {
        const idx = focusedIndex();
        if (idx === -1) return;
        const next = idx + delta;
        if (next < 0 || next >= entries.length) return;
        switchTo(entries[next]);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.entries

            delegate: Rectangle {
                id: pill

                required property var modelData

                readonly property var ws: modelData.ws
                readonly property bool focused: ws ? ws.focused : false
                // Active but not focused means it is showing on the other
                // monitor, which is worth distinguishing on a two-head setup.
                readonly property bool activeElsewhere: ws ? (ws.active && !ws.focused) : false
                readonly property bool urgent: ws ? ws.urgent : false
                readonly property bool occupied: {
                    if (!ws) return false;
                    if (ws.toplevels && ws.toplevels.values.length > 0) return true;
                    // toplevels can lag just after a workspace is created; the
                    // raw IPC object carries the count Hyprland last reported.
                    const raw = ws.lastIpcObject;
                    return raw && raw.windows > 0;
                }

                height: 20
                width: focused ? 26 : 20
                radius: 6

                color: {
                    if (urgent) return Theme.danger;
                    if (focused) return Theme.accent;
                    if (mouse.containsMouse) return Theme.hoverStrong;
                    if (activeElsewhere || occupied) return Theme.pill;
                    return "transparent";
                }

                border.width: activeElsewhere ? 1 : 0
                border.color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on color {
                    ColorAnimation { duration: 120 }
                }

                Text {
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    font.bold: pill.focused
                    color: {
                        if (pill.urgent || pill.focused) return "#1e1e2e";
                        if (pill.occupied || pill.activeElsewhere) return Theme.text;
                        return Theme.textFaint;
                    }

                    Behavior on color {
                        ColorAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.switchTo(pill.modelData)
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(ev) {
            root.cycle(ev.angleDelta.y > 0 ? -1 : 1);
        }
    }
}
