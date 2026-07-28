import QtQuick
import Quickshell

Item {
    id: root

    implicitWidth: content.implicitWidth + 14
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: mouse.containsMouse ? Theme.hover : "transparent"
    }

    Item {
        id: content
        anchors.centerIn: parent
        implicitWidth: bell.implicitWidth
        implicitHeight: 26

        Text {
            id: bell
            anchors.centerIn: parent
            text: NotificationService.dnd ? "󰂛" : "󰂚"
            color: NotificationService.dnd ? Theme.textDim : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: 14
        }

        // Unread count, tucked into the top-right of the glyph.
        Rectangle {
            visible: NotificationService.count > 0 && !NotificationService.dnd
            anchors.right: bell.right
            anchors.rightMargin: -4
            anchors.top: bell.top
            anchors.topMargin: -2
            radius: height / 2
            color: Theme.accent
            implicitHeight: 12
            implicitWidth: Math.max(12, badge.implicitWidth + 6)

            Text {
                id: badge
                anchors.centerIn: parent
                text: NotificationService.count > 9 ? "9+" : NotificationService.count
                color: "#1e1e2e"
                font.family: Theme.uiFont
                font.pixelSize: 8
                font.bold: true
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: function (ev) {
            if (ev.button === Qt.RightButton) {
                NotificationService.dnd = !NotificationService.dnd;
                return;
            }
            panel.anchorCenterX = root.mapToItem(null, root.width / 2, 0).x;
            panel.toggle();
        }
    }

    BarPopup {
        id: panel
        cardWidth: 340
        cardHeight: 44 + Math.min(Math.max(NotificationService.count, 1), 6) * 74

        Column {
            width: parent.width
            spacing: 6

            Item {
                width: parent.width
                height: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.bold: true
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Rectangle {
                        radius: 5
                        implicitHeight: 20
                        implicitWidth: dndLabel.implicitWidth + 14
                        color: NotificationService.dnd ? Theme.accent
                             : (dndMouse.containsMouse ? Theme.hoverStrong : Theme.pill)

                        Text {
                            id: dndLabel
                            anchors.centerIn: parent
                            text: "DND"
                            color: NotificationService.dnd ? "#1e1e2e" : Theme.textDim
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.bold: NotificationService.dnd
                        }

                        MouseArea {
                            id: dndMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: NotificationService.dnd = !NotificationService.dnd
                        }
                    }

                    Rectangle {
                        visible: NotificationService.count > 0
                        radius: 5
                        implicitHeight: 20
                        implicitWidth: clearLabel.implicitWidth + 14
                        color: clearMouse.containsMouse ? Theme.hoverStrong : Theme.pill

                        Text {
                            id: clearLabel
                            anchors.centerIn: parent
                            text: "Clear"
                            color: Theme.textDim
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                NotificationService.dismissAll();
                                panel.close();
                            }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Theme.border
            }

            Text {
                visible: NotificationService.count === 0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 20
                text: NotificationService.dnd ? "Do not disturb is on"
                                              : "No notifications"
                color: Theme.textFaint
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            ListView {
                width: parent.width
                height: panel.cardHeight - 64
                visible: NotificationService.count > 0
                clip: true
                spacing: 2
                model: NotificationService.list
                boundsBehavior: Flickable.StopAtBounds

                delegate: NotificationCard {
                    required property var modelData

                    width: ListView.view.width
                    notification: modelData
                    onDismissed: modelData.dismiss()
                }
            }
        }
    }
}
