import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

ShellRoot {
    PanelWindow {
        id: bar

        screen: Quickshell.screens.find(s => s.name === "DP-1") ?? Quickshell.screens[0]

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: 34
        color: "transparent"

        SystemClock {
            id: sysClock
            precision: SystemClock.Minutes
        }

        Rectangle {
            id: centerPill
            anchors.centerIn: parent
            radius: 8
            color: clockArea.containsMouse ? "#26ffffff" : "#1affffff"
            implicitHeight: 26
            implicitWidth: clockText.implicitWidth + 24

            Text {
                id: clockText
                anchors.centerIn: parent
                color: "#ffffff"
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                text: Qt.formatDateTime(sysClock.date, "hh:mm AP    ddd, MMM d")
            }

            MouseArea {
                id: clockArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: calendarPopup.toggle()
            }
        }

        // Left cluster: separate bubbles for each monitor's workspaces, then media
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                implicitWidth: dellWorkspaces.implicitWidth + 12

                WorkspacesModule {
                    id: dellWorkspaces
                    anchors.centerIn: parent
                    workspaceIds: [1, 2, 3]
                    labelOffset: 0
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                implicitWidth: benqWorkspaces.implicitWidth + 12

                WorkspacesModule {
                    id: benqWorkspaces
                    anchors.centerIn: parent
                    workspaceIds: [4, 5, 6]
                    labelOffset: 3
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                // MediaModule collapses itself to zero width when no player is
                // running, so this whole bubble disappears with it instead of
                // lingering as an empty pill.
                implicitWidth: mediaModule.active ? mediaModule.implicitWidth + 12 : 0
                visible: mediaModule.active
                clip: true

                MediaModule {
                    id: mediaModule
                    anchors.centerIn: parent
                }
            }
        }

        // Right cluster: a stats bubble, then tray | notifications | bluetooth | network | volume | power
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                implicitWidth: downloadSpeedModule.implicitWidth + 12

                DownloadSpeedModule {
                    id: downloadSpeedModule
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                implicitWidth: statsModule.implicitWidth + 12

                SystemStatsModule {
                    id: statsModule
                    anchors.centerIn: parent
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                radius: 8
                color: "#1affffff"
                implicitHeight: 26
                implicitWidth: rightRow.implicitWidth + 12

                Row {
                    id: rightRow
                    anchors.centerIn: parent
                    spacing: 2

                    TrayModule {
                        anchors.verticalCenter: parent.verticalCenter
                        barWindow: bar
                    }

                    NotificationModule {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    BluetoothModule {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    NetworkModule {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    VolumeModule {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PowerModule {
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }

    CalendarPopup {
        id: calendarPopup
        barHeight: 34
    }

    // Popup notifications, replacing swaync's.
    NotificationToasts {}
}
