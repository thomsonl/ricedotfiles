pragma Singleton
import QtQuick

QtObject {
    // Inter for text on the left/right clusters; the centre clock and calendar
    // deliberately stay on the Nerd Font. Glyphs always need the Nerd Font,
    // since Inter has none of the icon codepoints.
    readonly property string uiFont: "Inter"
    readonly property string iconFont: "Hack Nerd Font"

    readonly property color text: "#ffffff"
    readonly property color textDim: "#80ffffff"
    readonly property color textFaint: "#40ffffff"

    readonly property color pill: "#1affffff"
    readonly property color hover: "#1affffff"
    readonly property color hoverStrong: "#26ffffff"

    readonly property color surface: "#f21e1e2e"
    readonly property color border: "#14ffffff"

    readonly property color danger: "#ed8796"
    readonly property color accent: "#8aadf4"
}
