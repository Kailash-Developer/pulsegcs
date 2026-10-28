pragma Singleton
import QtQuick

QtObject {
    property var globalPalette: QtObject {
        property int globalTheme: 1
    }
    property bool mockLinkRunning: false
    function startGenericMockLink(sendStatusText, enableCamera, enableGimbal, enableProximity, videoStreamType) {
        mockLinkRunning = true
    }
    function startAPMArduCopterMockLink(sendStatusText, enableCamera, enableGimbal, enableProximity, apmStartFreshParams, videoStreamType) {
        mockLinkRunning = true
    }
    function stopOneMockLink() {
        mockLinkRunning = false
    }
}

