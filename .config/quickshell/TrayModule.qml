import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Item {
    id: root

    // The bar window, needed as the parent for dbus menu popups.
    property var barWindow

    implicitWidth: 26
    implicitHeight: 26

    // Solaar's AppIndicator-based tray icon never wires up a real SNI
    // "Activate" action (AppIndicator/Ayatana only ever shows the menu), so
    // modelData.activate() is a no-op for it. Solaar is a single-instance GTK
    // app though, so re-running it just raises/shows its existing window.
    Process { id: solaarShow; command: ["solaar"] }

    function focusSpotifyWorkspace() {
        const toplevels = Hyprland.toplevels.values
        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i]
            if (tl.wmClass && tl.wmClass.toLowerCase() === "spotify") {
                if (tl.workspace) tl.workspace.activate()
                return
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: triggerMouse.containsMouse ? Theme.hover : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: "󰀻"
        color: Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 14
    }

    MouseArea {
        id: triggerMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            panel.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x
            panel.toggle()
        }
    }

    BarPopup {
        id: panel
        cardWidth: 140
        cardHeight: 56

        Row {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: SystemTray.items

                delegate: Item {
                    required property var modelData

                    width: 28
                    height: 28

                    // A theme icon that doesn't resolve still loads "successfully" as Qt's
                    // magenta placeholder, so status can't be trusted — check the name instead.
                    // Non-theme sources (embedded pixmaps) are always fine.
                    readonly property bool iconOk: {
                        var s = modelData.icon
                        if (!s) return false
                        var prefix = "image://icon/"
                        if (s.indexOf(prefix) !== 0) return true
                        var name = s.substring(prefix.length)
                        var q = name.indexOf("?")
                        if (q >= 0) name = name.substring(0, q)
                        return Quickshell.hasThemeIcon(name)
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: itemMouse.containsMouse ? Theme.hover : "transparent"
                    }

                    IconImage {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: 18
                        height: 18
                        asynchronous: true
                        source: modelData.icon
                        visible: iconOk && status === Image.Ready
                    }

                    // Themes are missing icons often enough that the alternative here is
                    // Qt's magenta "broken image" checkerboard sitting in the dropdown.
                    Text {
                        anchors.centerIn: parent
                        visible: !trayIcon.visible
                        text: "󰀻"
                        color: Theme.text
                        font.family: Theme.iconFont
                        font.pixelSize: 14
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                        onClicked: function(ev) {
                            if (ev.button === Qt.LeftButton && modelData.id === "indicator-solaar") {
                                solaarShow.running = true
                                return
                            }
                            // Items that only expose a menu have no useful activate().
                            if (ev.button === Qt.RightButton || modelData.onlyMenu) {
                                if (modelData.hasMenu) {
                                    modelData.display(root.barWindow, width / 2, height)
                                }
                            } else if (ev.button === Qt.MiddleButton) {
                                modelData.secondaryActivate()
                            } else {
                                modelData.activate()
                                if (modelData.id === "spotify-client") root.focusSpotifyWorkspace()
                            }
                        }
                    }
                }
            }
        }
    }
}
