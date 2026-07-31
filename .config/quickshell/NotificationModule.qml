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
        // Grows with the notifications' actual measured height (cards vary --
        // body text wraps, actions add a row) instead of assuming a fixed
        // per-row height, up to 80% of the screen height -- past that the
        // list scrolls (SnapList) rather than the popup growing further.
        // 55 is the chrome around the list: header (22) + divider (1) +
        // holder margins (20) + two 6px column gaps.
        cardHeight: Math.max(118, Math.min(notifList.contentHeight + 55, panel.height * 0.8))

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

            Item {
                width: parent.width
                height: panel.cardHeight - 55
                visible: NotificationService.count > 0

                SnapList {
                    id: notifList
                    width: parent.width - 6
                    height: parent.height
                    rowHeight: 76
                    spacing: 2
                    source: NotificationService.list

                    delegate: NotificationCard {
                        required property var modelData

                        width: ListView.view.width
                        notification: modelData
                        onDismissed: modelData.dismiss()
                    }
                }

                // Slim scroll indicator; only shows once the list is taller than
                // its viewport.
                Rectangle {
                    visible: notifList.contentHeight > notifList.height
                    anchors.right: parent.right
                    y: notifList.visibleArea.yPosition * notifList.height
                    width: 3
                    height: Math.max(16, notifList.visibleArea.heightRatio * notifList.height)
                    radius: 1.5
                    color: Theme.textFaint
                }
            }
        }
    }
}
