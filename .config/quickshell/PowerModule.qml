import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Item {
    id: root

    implicitWidth: 26
    implicitHeight: 26

    Process { id: runner }

    function run(cmd) {
        runner.command = cmd
        runner.running = true
        menu.close()
    }

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Text {
        anchors.centerIn: parent
        text: "⏻"
        color: mouse.containsMouse ? Theme.danger : Theme.text
        font.family: Theme.iconFont
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            menu.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x
            menu.toggle()
        }
    }

    BarPopup {
        id: menu
        cardWidth: 190
        cardHeight: actions.implicitHeight + 20

        Column {
            id: actions
            width: parent.width
            spacing: 2

            Repeater {
                model: [
                    { label: "Lock",     glyph: "󰌾", cmd: ["hyprlock"],            danger: false },
                    { label: "Log out",  glyph: "󰍃", cmd: ["hyprctl", "dispatch", "exit"], danger: false },
                    { label: "Reboot",   glyph: "󰜉", cmd: ["systemctl", "reboot"], danger: true },
                    { label: "Shutdown", glyph: "󰐥", cmd: ["systemctl", "poweroff"], danger: true }
                ]

                delegate: Rectangle {
                    required property var modelData

                    width: parent.width
                    height: 32
                    radius: 6
                    color: rowMouse.containsMouse ? Theme.hover : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.glyph
                            color: modelData.danger && rowMouse.containsMouse
                                   ? Theme.danger : Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 14
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.label
                            color: modelData.danger && rowMouse.containsMouse
                                   ? Theme.danger : Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.run(modelData.cmd)
                    }
                }
            }
        }
    }
}
