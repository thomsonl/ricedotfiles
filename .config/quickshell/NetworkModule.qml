import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Item {
    id: root

    readonly property var devices: Networking.devices ? Networking.devices.values : []

    readonly property var wifiDevice: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type === DeviceType.Wifi) return devices[i]
        }
        return null
    }

    // Wired wins when both are up — it's the connection actually carrying traffic.
    readonly property var activeDevice: {
        var wifi = null
        for (var i = 0; i < devices.length; i++) {
            var d = devices[i]
            if (!d.connected) continue
            if (d.type === DeviceType.Wired) return d
            if (d.type === DeviceType.Wifi && !wifi) wifi = d
        }
        return wifi
    }

    readonly property bool isWired: activeDevice && activeDevice.type === DeviceType.Wired
    readonly property bool isWifi: activeDevice && activeDevice.type === DeviceType.Wifi

    readonly property var connectedWifi: {
        if (!wifiDevice || !wifiDevice.networks) return null
        var nets = wifiDevice.networks.values
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i]
        }
        return null
    }

    // Strongest signal first, connected pinned to the top.
    readonly property var wifiNetworks: {
        if (!wifiDevice || !wifiDevice.networks) return []
        var nets = wifiDevice.networks.values.slice()
        nets.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1
            return b.signalStrength - a.signalStrength
        })
        return nets
    }

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    Process { id: editor; command: ["nm-connection-editor"] }

    function icon() {
        if (isWired) return "󰈀"
        if (isWifi) return signalGlyph(connectedWifi ? connectedWifi.signalStrength : 1)
        if (!Networking.wifiEnabled) return "󰤮"
        return "󰲛"
    }

    function signalGlyph(s) {
        if (s >= 0.8) return "󰤨"
        if (s >= 0.6) return "󰤥"
        if (s >= 0.4) return "󰤢"
        if (s >= 0.2) return "󰤟"
        return "󰤯"
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon()
            color: root.activeDevice ? Theme.text : Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        // Wired needs no label; the SSID is only useful info on wifi.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.isWifi && root.connectedWifi
            text: root.connectedWifi ? root.connectedWifi.name : ""
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            panel.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x
            if (!panel.visible && root.wifiDevice) root.wifiDevice.scannerEnabled = true
            panel.toggle()
        }
        onWheel: {}
    }

    BarPopup {
        id: panel
        cardWidth: 280
        cardHeight: 92 + Math.max(1, Math.min(root.wifiNetworks.length, 6)) * 34

        // Scanning burns power; only do it while the panel is actually open.
        onVisibleChanged: if (!visible && root.wifiDevice) root.wifiDevice.scannerEnabled = false

        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Wi-Fi"
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    font.bold: true
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 20
                    radius: 10
                    color: Networking.wifiEnabled ? Theme.accent : "#33ffffff"

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: Networking.wifiEnabled ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }
            }

            // Wired is easy to forget about when a wifi list is staring at you.
            Text {
                visible: root.isWired
                width: parent.width
                text: "󰈀  Connected via Ethernet"
                color: Theme.textDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                height: 20
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Text {
                visible: root.wifiNetworks.length === 0
                text: Networking.wifiEnabled ? "Scanning…" : "Wi-Fi is off"
                color: Theme.textDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                height: 34
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: root.wifiNetworks.slice(0, 6)

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 34
                    radius: 6
                    color: netMouse.containsMouse ? Theme.hover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.signalGlyph(modelData.signalStrength)
                            color: modelData.connected ? Theme.accent : Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: modelData.name
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: 190
                            }
                            Text {
                                visible: modelData.connected || modelData.known
                                text: modelData.connected ? "Connected" : "Saved"
                                color: Theme.textDim
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.connected) {
                                modelData.disconnect()
                            } else if (modelData.known) {
                                modelData.connect()
                            } else {
                                // New networks need a passphrase, which needs a
                                // text field we don't have here.
                                editor.running = true
                                panel.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
