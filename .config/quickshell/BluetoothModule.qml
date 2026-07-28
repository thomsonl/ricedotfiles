import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

Item {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false

    readonly property var devices: {
        if (!Bluetooth.devices) return []
        var all = Bluetooth.devices.values
        var out = []
        for (var i = 0; i < all.length; i++) {
            // Unpaired strangers from a scan would flood the list.
            if (all[i].paired || all[i].connected) out.push(all[i])
        }
        return out
    }

    readonly property bool anyConnected: {
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].connected) return true
        }
        return false
    }

    implicitWidth: 26
    implicitHeight: 26

    Process { id: manager; command: ["blueman-manager"] }

    function icon() {
        if (!enabled) return "󰂲"
        return anyConnected ? "󰂱" : "󰂯"
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: root.icon()
        color: root.enabled ? Theme.text : Theme.textDim
        font.family: Theme.iconFont
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse
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
        cardWidth: 260
        cardHeight: 56 + Math.max(1, Math.min(root.devices.length, 6)) * 34 + 30

        Column {
            width: parent.width
            spacing: 6

            // Header: title + adapter toggle
            Item {
                width: parent.width
                height: 24

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Bluetooth"
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
                    color: root.enabled ? Theme.accent : "#33ffffff"

                    Rectangle {
                        width: 16
                        height: 16
                        radius: 8
                        color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                        x: root.enabled ? parent.width - width - 2 : 2
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Text {
                visible: root.devices.length === 0
                text: root.enabled ? "No paired devices" : "Bluetooth is off"
                color: Theme.textDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                height: 34
                verticalAlignment: Text.AlignVCenter
            }

            Repeater {
                model: root.devices

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 34
                    radius: 6
                    color: devMouse.containsMouse ? Theme.hover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.connected ? "󰂱" : "󰂯"
                            color: modelData.connected ? Theme.accent : Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            Text {
                                text: modelData.name || modelData.deviceName || modelData.address
                                color: Theme.text
                                font.family: Theme.uiFont
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: 170
                            }
                            Text {
                                visible: modelData.connected
                                text: modelData.batteryAvailable
                                      ? "Connected · " + Math.round(modelData.battery * 100) + "%"
                                      : "Connected"
                                color: Theme.textDim
                                font.family: Theme.uiFont
                                font.pixelSize: 10
                            }
                        }
                    }

                    MouseArea {
                        id: devMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: modelData.connected = !modelData.connected
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Rectangle {
                width: parent.width
                height: 26
                radius: 6
                color: bmMouse.containsMouse ? Theme.hover : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "Open Blueman"
                    color: Theme.textDim
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }

                MouseArea {
                    id: bmMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { manager.running = true; panel.close() }
                }
            }
        }
    }
}
