import QtQuick

QtObject {
    enum Theme {
        Light = 0,
        Dark = 1
    }

    property int globalTheme: 1
    readonly property color window: "#12171E"
    readonly property color windowShade: "#1C242E"
    readonly property color text: "#FFFFFF"
}

