import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: popup

    visible: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Without this, the full-screen click-catcher below gets auto-pushed below
    // the bar's exclusive zone (confirmed via `hyprctl layers`: it only spanned
    // y=34..1080), so clicking the bar itself -- including the clock that opened
    // this -- never reached it. Matches the fix applied to BarPopup.qml.
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    property int barHeight: 34
    property var today: new Date()
    property var monthCursor: new Date(today.getFullYear(), today.getMonth(), 1)
    property var selectedDate: today
    // dateKey -> array of {title, startTime, endTime, allDay, location}
    property var eventsByDate: ({})
    property bool loading: false
    // Month window currently held in eventsByDate: [fetchedStart, fetchedEnd).
    // Set only once data actually lands, so a failed fetch is retried.
    property var fetchedStart: null
    property var fetchedEnd: null
    property var pendingStart: null
    property var pendingEnd: null

    function dateKey(d) {
        return Qt.formatDate(d, "yyyy-MM-dd")
    }

    // Parses gcalcli's "yyyy-MM-dd" columns into a local-midnight Date.
    // Doing this by hand (rather than `new Date(string)`) avoids the
    // built-in parser treating it as UTC and landing on the wrong local day.
    function parseYMD(s) {
        var parts = s.split("-")
        return new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10))
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function haveMonth(d) {
        return fetchedStart !== null && fetchedEnd !== null
            && d >= fetchedStart && d < fetchedEnd
    }

    function shiftMonth(delta) {
        monthCursor = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + delta, 1)
        // Only hit gcalcli again when navigating outside the fetched window.
        if (!haveMonth(monthCursor)) refresh()
    }

    function toggle() {
        if (visible) {
            close()
        } else {
            open()
        }
    }

    function open() {
        PopupManager.requestOpen(popup)
        var now = new Date()
        today = now
        monthCursor = new Date(now.getFullYear(), now.getMonth(), 1)
        selectedDate = now
        visible = true
        refresh()
    }

    function close() {
        visible = false
        PopupManager.notifyClosed(popup)
    }

    // Pulls a 13-month window centred on monthCursor. Called on open, and again
    // whenever navigation leaves the window that window covers.
    function refresh() {
        var start = new Date(monthCursor.getFullYear(), monthCursor.getMonth() - 6, 1)
        var end = new Date(monthCursor.getFullYear(), monthCursor.getMonth() + 7, 1)
        pendingStart = start
        pendingEnd = end
        loading = true
        gcalProc.command = [
            "gcalcli", "--nocolor", "agenda", "--tsv", "--details", "all",
            Qt.formatDate(start, "yyyy-MM-dd"),
            Qt.formatDate(end, "yyyy-MM-dd")
        ]
        gcalProc.running = true
    }

    Process {
        id: gcalProc
        stdout: StdioCollector { id: gcalStdout }
        // gcalcli failures (e.g. an expired/revoked OAuth token) print their
        // traceback to stderr and exit non-zero, leaving stdout empty. That
        // used to still get parsed into an empty-but-"successfully fetched"
        // map below, which then blocked the next refresh() until navigation
        // moved off the cached window -- a real fetch failure looked
        // identical to "this month genuinely has no events." Gating on
        // exitCode leaves a failed run unfetched so it's retried on the next
        // open()/navigation instead of caching in the empty result.
        onExited: (exitCode, exitStatus) => {
            loading = false
            if (exitCode !== 0) return

            var map = {}
            var lines = gcalStdout.text.split("\n")
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (line.length === 0 || line.indexOf("id\t") === 0) continue
                var cols = line.split("\t")
                if (cols.length < 10) continue
                var startDateStr = cols[1]
                var startTime = cols[2]
                var endDateStr = cols[3]
                var endTime = cols[4]
                var title = cols[9]
                var location = cols[10]
                if (!startDateStr) continue
                var isAllDay = startTime.length === 0
                var event = {
                    title: title,
                    startTime: startTime,
                    endTime: endTime,
                    allDay: isAllDay,
                    location: location
                }

                // Enter the event under every date it spans, not just its
                // start date, or it vanishes from the grid dot/agenda on
                // every day but the first. All-day events use gcalcli's
                // (Google's) exclusive end_date -- a single-day all-day
                // event's end_date is the day *after* -- while timed events
                // use an inclusive one (the actual date the end time falls
                // on). Capped at a year of days as a sanity backstop against
                // malformed rows; a real event should never hit it.
                var day = parseYMD(startDateStr)
                var endDay = endDateStr ? parseYMD(endDateStr) : day
                for (var guard = 0; guard < 366; guard++) {
                    if (isAllDay ? !(day < endDay) : !(day <= endDay)) break
                    var key = dateKey(day)
                    if (!map[key]) map[key] = []
                    map[key].push(event)
                    day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)
                }
            }
            eventsByDate = map
            fetchedStart = pendingStart
            fetchedEnd = pendingEnd
        }
    }

    // Full-screen click-catcher: click anywhere outside the card closes the popup.
    // Pointing-hand cursor since, once open, this is what's actually under the
    // pointer everywhere -- including back over the clock that opened it.
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
    // this popup. See BarPopup.qml, which has the identical fix.
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
        width: 580
        // Sized off the calendar column's actual content instead of a fixed
        // guess, so there's no leftover blank space below the day grid.
        height: leftColumn.implicitHeight + 24
        anchors.top: parent.top
        // Now that exclusionMode: Ignore stops the overlay layer from being
        // auto-pushed below the bar, the card has to clear it by hand.
        anchors.topMargin: barHeight + 6
        anchors.horizontalCenter: parent.horizontalCenter
        radius: 8
        color: "#f21e1e2e"
        border.color: "#14ffffff"
        border.width: 1

        // Absorb clicks so they don't fall through to the full-screen closer above.
        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // LEFT: month grid
            ColumnLayout {
                id: leftColumn
                Layout.preferredWidth: 300
                Layout.minimumWidth: 300
                Layout.maximumWidth: 300
                spacing: 4

                // Month header
                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "‹"
                        color: "#ffffff"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 16
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shiftMonth(-1) }
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        color: "#ffffff"
                        font.family: "Hack Nerd Font"
                        font.bold: true
                        font.pixelSize: 14
                        text: Qt.formatDate(monthCursor, "MMMM yyyy")
                    }
                    Text {
                        text: "›"
                        color: "#ffffff"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 16
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shiftMonth(1) }
                    }
                }

                // Weekday header
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 0
                    Repeater {
                        model: ["S", "M", "T", "W", "T", "F", "S"]
                        delegate: Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            color: "#80ffffff"
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 11
                            text: modelData
                        }
                    }
                }

                // Day grid
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 0

                    Repeater {
                        model: 42
                        delegate: Item {
                            id: cellRoot
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            property var cellDate: {
                                var firstWeekday = new Date(monthCursor.getFullYear(), monthCursor.getMonth(), 1).getDay()
                                return new Date(monthCursor.getFullYear(), monthCursor.getMonth(), 1 - firstWeekday + index)
                            }
                            property bool inMonth: cellDate.getMonth() === monthCursor.getMonth()
                            property bool isToday: sameDay(cellDate, today)
                            property bool isSelected: sameDay(cellDate, selectedDate)
                            property bool hasEvents: !!eventsByDate[dateKey(cellDate)]

                            Rectangle {
                                anchors.centerIn: parent
                                width: 26
                                height: 26
                                radius: 13
                                color: isSelected ? "#ffffff" : (isToday ? "#1affffff" : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: cellDate.getDate()
                                    font.family: "Hack Nerd Font"
                                    color: isSelected ? "#1e1e2e" : (inMonth ? "#ffffff" : "#40ffffff")
                                    font.pixelSize: 12
                                }
                            }

                            Rectangle {
                                visible: hasEvents && !isSelected
                                width: 4
                                height: 4
                                radius: 2
                                color: "#80ffffff"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: selectedDate = cellDate
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: "#14ffffff"
            }

            // RIGHT: agenda for selected day
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                // Pinned so long event titles / month names can't reflow the column
                Layout.minimumWidth: 0
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    color: "#ffffff"
                    font.family: "Hack Nerd Font"
                    font.bold: true
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    text: Qt.formatDate(selectedDate, "dddd, MMM d")
                }

                Text {
                    visible: loading
                    color: "#80ffffff"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                    text: "Loading…"
                }

                Text {
                    visible: !loading && (eventsByDate[dateKey(selectedDate)] || []).length === 0
                    color: "#80ffffff"
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 11
                    text: "No events"
                }

                ListView {
                    Layout.fillWidth: true
                    // Always occupies the remaining space, even while loading, so the
                    // date header stays pinned to the top instead of being centred.
                    Layout.fillHeight: true
                    clip: true
                    spacing: 8
                    model: loading ? [] : (eventsByDate[dateKey(selectedDate)] || [])

                    delegate: ColumnLayout {
                        width: ListView.view.width
                        spacing: 1

                        Text {
                            color: "#80ffffff"
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 10
                            text: modelData.allDay
                                  ? "All day"
                                  : (modelData.endTime
                                     ? modelData.startTime + " – " + modelData.endTime
                                     : modelData.startTime)
                        }
                        Text {
                            Layout.fillWidth: true
                            color: "#ffffff"
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 11
                            wrapMode: Text.WordWrap
                            text: modelData.title
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: !!modelData.location
                            color: "#66ffffff"
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            text: modelData.location
                        }
                    }
                }
            }
        }
    }
}
