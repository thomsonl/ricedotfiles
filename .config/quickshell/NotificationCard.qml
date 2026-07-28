import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications

// One themed notification, shared by the dropdown list and the toast stack so
// both always look the same.
Item {
    id: card

    required property var notification
    // Toasts sit on their own surface and need a filled background; rows inside
    // the dropdown sit on the popup card and only tint on hover.
    property bool standalone: false

    signal dismissed

    readonly property string iconSource: {
        if (!notification) return "";
        if (notification.image) return notification.image;
        const name = notification.appIcon;
        // A theme icon that does not resolve still loads as Image.Ready (Qt's
        // magenta checkerboard), so ask whether it exists rather than trusting
        // the load status later.
        if (name && Quickshell.hasThemeIcon(name)) return Quickshell.iconPath(name);
        return "";
    }

    readonly property bool critical:
        notification && notification.urgency === NotificationUrgency.Critical

    implicitHeight: Math.max(40, layout.implicitHeight + 20)

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: card.standalone ? Theme.surface
                               : (hover.hovered ? Theme.hover : "transparent")
        border.width: card.standalone ? 1 : 0
        border.color: card.critical ? Theme.danger : Theme.border
    }

    // A critical notification gets a colour bar rather than a louder background,
    // which would fight the rest of the bar's styling.
    Rectangle {
        visible: card.critical
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: parent.height - 16
        radius: 1
        color: Theme.danger
    }

    HoverHandler { id: hover }

    Item {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        implicitHeight: Math.max(icon.height, textCol.implicitHeight)

        Item {
            id: icon
            width: card.iconSource ? 32 : 0
            height: 32
            visible: card.iconSource !== ""
            anchors.left: parent.left
            anchors.top: parent.top

            Image {
                id: iconImage
                anchors.fill: parent
                source: card.iconSource
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 64
                sourceSize.height: 64
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: iconImage
                maskEnabled: true
                maskSource: iconMask
                visible: iconImage.status === Image.Ready
            }

            Rectangle {
                id: iconMask
                anchors.fill: parent
                radius: 6
                visible: false
                layer.enabled: true
            }
        }

        Column {
            id: textCol
            anchors.left: icon.visible ? icon.right : parent.left
            anchors.leftMargin: icon.visible ? 10 : 0
            anchors.right: closeButton.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Row {
                spacing: 6
                width: parent.width

                Text {
                    text: card.notification ? card.notification.appName : ""
                    color: Theme.textDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - timeText.implicitWidth - 6)
                }

                Text {
                    id: timeText
                    text: card.notification ? NotificationService.relTime(card.notification) : ""
                    color: Theme.textFaint
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }

            Text {
                text: card.notification ? card.notification.summary : ""
                color: Theme.text
                font.family: Theme.uiFont
                font.pixelSize: 12
                font.bold: true
                width: parent.width
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                text: card.notification ? card.notification.body : ""
                visible: text !== ""
                color: Theme.textDim
                font.family: Theme.uiFont
                font.pixelSize: 11
                width: parent.width
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 3
                // Bodies may carry basic markup since bodyMarkupSupported is on.
                textFormat: Text.StyledText
            }

            Row {
                spacing: 6
                visible: card.notification && card.notification.actions.length > 0
                topPadding: 4

                Repeater {
                    model: card.notification ? card.notification.actions : []

                    delegate: Rectangle {
                        required property var modelData

                        radius: 5
                        color: actionMouse.containsMouse ? Theme.hoverStrong : Theme.pill
                        implicitWidth: actionLabel.implicitWidth + 16
                        implicitHeight: 22

                        Text {
                            id: actionLabel
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            color: Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                        }

                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                parent.modelData.invoke();
                                card.dismissed();
                            }
                        }
                    }
                }
            }
        }

        Text {
            id: closeButton
            anchors.right: parent.right
            anchors.top: parent.top
            text: "󰅖"
            color: closeMouse.containsMouse ? Theme.danger : Theme.textFaint
            font.family: Theme.iconFont
            font.pixelSize: 11
            opacity: hover.hovered || card.standalone ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: card.dismissed()
            }
        }
    }
}
