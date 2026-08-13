import QtQuick
import Quickshell.Io

// Current weather for [redacted] -- lat/long fixed by request
// rather than IP-geolocated, so it doesn't wobble on VPN/travel and needs no
// extra lookup on startup. Backed by Open-Meteo (free, no API key, no signup)
// fetched via curl rather than QML's XMLHttpRequest, matching how
// CalendarPopup already shells out to gcalcli for its own data.
Row {
    id: root

    spacing: 5
    height: 26

    readonly property real latitude: 0.0
    readonly property real longitude: 0.0

    property string glyph: ""
    property string tempF: ""
    property bool haveData: false

    // Collapses Open-Meteo's ~28 WMO weather codes down to the handful of
    // categories that actually have a distinct icon (sunny/cloudy/rain/snow,
    // plus fog and thunderstorms since they're common enough to bother with),
    // each with a day and a night variant. Full code list:
    // https://open-meteo.com/en/docs -> "WMO Weather interpretation codes"
    function iconFor(code, isDay) {
        if (code === 0) return isDay ? "" : ""
        if (code === 1 || code === 2) return isDay ? "" : ""
        if (code === 3) return ""
        if (code === 45 || code === 48) return isDay ? "" : ""
        if (code === 51 || code === 53 || code === 55 || code === 56 || code === 57)
            return isDay ? "" : ""
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82))
            return isDay ? "" : ""
        if ((code >= 71 && code <= 77) || code === 85 || code === 86)
            return isDay ? "" : ""
        if (code === 95 || code === 96 || code === 99)
            return isDay ? "" : ""
        return isDay ? "" : ""
    }

    Process {
        id: fetchProc
        command: ["curl", "-s", "--max-time", "10",
            "https://api.open-meteo.com/v1/forecast?latitude=" + root.latitude
            + "&longitude=" + root.longitude
            + "&current=temperature_2m,weather_code,is_day&temperature_unit=fahrenheit&timezone=auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const cur = JSON.parse(text).current
                    root.tempF = Math.round(cur.temperature_2m) + "°"
                    root.glyph = root.iconFor(cur.weather_code, cur.is_day === 1)
                    root.haveData = true
                } catch (e) {
                    // Offline or a bad response -- leave the last-good reading
                    // on screen rather than blanking the pill over one poll.
                }
            }
        }
    }

    // Weather doesn't change fast enough to justify polling more often, and
    // this is a real network call unlike everything else in the bar.
    Timer {
        interval: 15 * 60 * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: fetchProc.running = true
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.haveData
        text: root.glyph
        font.family: Theme.iconFont
        font.pixelSize: 14
        color: Theme.text
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.haveData ? root.tempF : "…"
        font.family: Theme.uiFont
        font.pixelSize: 11
        color: Theme.text
    }
}
