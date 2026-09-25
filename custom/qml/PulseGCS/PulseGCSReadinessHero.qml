import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    // Readiness Status: "ready" (ok), "not_ready" (err), "checking" (accent), "unknown" (neutral)
    property string status: "unknown"
    property string title: ""
    property string subtitle: ""
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    // Telemetry chip values
    property string batteryText: ""
    property string gpsText: ""
    property string linkText: ""

    implicitWidth: 380
    implicitHeight: Math.max(92, mainLayout.implicitHeight + 28)
    radius: PulseGCSTokens.radiusCard

    color: isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
    border.color: {
        if (root.status === "ready" || root.status === "ok") {
            return isOutdoor ? Qt.rgba(23/255, 138/255, 87/255, 0.30) : Qt.rgba(62/255, 213/255, 152/255, 0.30)
        }
        if (root.status === "not_ready" || root.status === "err" || root.status === "error") {
            return isOutdoor ? Qt.rgba(193/255, 58/255, 36/255, 0.35) : Qt.rgba(240/255, 104/255, 79/255, 0.35)
        }
        if (root.status === "checking") {
            return isOutdoor ? Qt.rgba(0/255, 146/255, 168/255, 0.35) : Qt.rgba(47/255, 208/255, 232/255, 0.35)
        }
        return isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    }
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // 56x56 Status Ring Icon Badge
            Rectangle {
                id: statusRing
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 27

                color: {
                    if (root.status === "ready" || root.status === "ok") {
                        return isOutdoor ? PulseGCSTokens.outdoorOkBg : PulseGCSTokens.okBg
                    }
                    if (root.status === "not_ready" || root.status === "err" || root.status === "error") {
                        return isOutdoor ? PulseGCSTokens.outdoorErrBg : PulseGCSTokens.errBg
                    }
                    if (root.status === "checking") {
                        return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
                    }
                    return isOutdoor ? PulseGCSTokens.outdoorNeutralBg : PulseGCSTokens.neutralBg
                }

                border.color: {
                    if (root.status === "ready" || root.status === "ok") {
                        return isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok
                    }
                    if (root.status === "not_ready" || root.status === "err" || root.status === "error") {
                        return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                    }
                    if (root.status === "checking") {
                        return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
                    }
                    return isOutdoor ? PulseGCSTokens.outdoorNeutral : PulseGCSTokens.neutral
                }
                border.width: 3

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (root.status === "ready" || root.status === "ok") return "✓"
                        if (root.status === "not_ready" || root.status === "err" || root.status === "error") return "!"
                        if (root.status === "checking") return "…"
                        return "?"
                    }
                    font.pixelSize: 22
                    font.bold: true
                    color: statusRing.border.color
                    renderType: Text.QtRendering
                }

                // Pulsing animation for checking state
                SequentialAnimation on scale {
                    running: root.status === "checking"
                    loops: Animation.Infinite
                    PropertyAnimation { to: 1.05; duration: 600; easing.type: Easing.InOutQuad }
                    PropertyAnimation { to: 0.95; duration: 600; easing.type: Easing.InOutQuad }
                }
            }

            // Titles Column
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: {
                            if (root.title.length > 0) return root.title
                            if (root.status === "ready" || root.status === "ok") return qsTr("Ready to Fly")
                            if (root.status === "not_ready" || root.status === "err" || root.status === "error") return qsTr("Not Ready to Fly")
                            if (root.status === "checking") return qsTr("Checking Aircraft Readiness...")
                            return qsTr("Readiness Unknown")
                        }
                        font.pixelSize: 15
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        renderType: Text.QtRendering
                    }

                    PulseGCSStatusPill {
                        status: {
                            if (root.status === "ready" || root.status === "ok") return "ok"
                            if (root.status === "not_ready" || root.status === "err" || root.status === "error") return "err"
                            if (root.status === "checking") return "accent"
                            return "neutral"
                        }
                        text: {
                            if (root.status === "ready" || root.status === "ok") return qsTr("READY")
                            if (root.status === "not_ready" || root.status === "err" || root.status === "error") return qsTr("BLOCKED")
                            if (root.status === "checking") return qsTr("CHECKING")
                            return qsTr("UNKNOWN")
                        }
                        pulsing: root.status === "checking"
                        isOutdoor: root.isOutdoor
                    }
                }

                Text {
                    text: {
                        if (root.subtitle.length > 0) return root.subtitle
                        if (root.status === "ready" || root.status === "ok") return qsTr("All pre-arm telemetry & safety checks passed")
                        if (root.status === "not_ready" || root.status === "err" || root.status === "error") return qsTr("Action required before safe takeoff / arming")
                        if (root.status === "checking") return qsTr("Evaluating sensors, calibration, and arming checks")
                        return qsTr("Connect aircraft to evaluate pre-flight readiness")
                    }
                    font.pixelSize: 12
                    color: PulseGCSTokens.metaText(root.isOutdoor)
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    renderType: Text.QtRendering
                }
            }
        }

        // Telemetry quick chips row (when available)
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.batteryText.length > 0 || root.gpsText.length > 0 || root.linkText.length > 0

            Rectangle {
                visible: root.batteryText.length > 0
                height: 24
                radius: 4
                color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
                border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
                border.width: 1
                implicitWidth: batRow.implicitWidth + 12

                Row {
                    id: batRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "⚡ " + root.batteryText
                        font.pixelSize: 10
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }
            }

            Rectangle {
                visible: root.gpsText.length > 0
                height: 24
                radius: 4
                color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
                border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
                border.width: 1
                implicitWidth: gpsRow.implicitWidth + 12

                Row {
                    id: gpsRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "🛰 " + root.gpsText
                        font.pixelSize: 10
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }
            }

            Rectangle {
                visible: root.linkText.length > 0
                height: 24
                radius: 4
                color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
                border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
                border.width: 1
                implicitWidth: linkRow.implicitWidth + 12

                Row {
                    id: linkRow
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: "📶 " + root.linkText
                        font.pixelSize: 10
                        font.bold: true
                        color: PulseGCSTokens.primaryText(root.isOutdoor)
                        renderType: Text.QtRendering
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
