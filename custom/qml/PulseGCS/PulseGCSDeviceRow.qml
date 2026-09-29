import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

Rectangle {
    id: root

    property string deviceName: ""
    property string deviceAddress: ""
    property string subtitleText: ""
    property string transportType: "bluetooth" // bluetooth, ble, wifi, serial, udp
    property bool isSkyx: false
    property bool showIdentityBadge: true
    property int rssi: 0
    property int signalLevel: -1
    property bool showSignal: true
    property string status: "" // connected, connecting, paired, neutral
    property string statusText: ""
    property bool statusPulsing: false

    property bool isSelected: false
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    // Action button slots or signals
    property string primaryActionText: ""
    property bool primaryActionEnabled: true
    property bool primaryActionIsDanger: false
    property string secondaryActionText: ""
    property bool secondaryActionEnabled: true

    signal primaryActionClicked()
    signal secondaryActionClicked()
    signal clicked()

    implicitWidth: 380
    implicitHeight: Math.max(52, rowLayout.implicitHeight + 16)
    radius: 8

    color: {
        if (root.isSelected) {
            return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
        }
        if (mouseArea.containsMouse) {
            return isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
        }
        return isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
    }

    border.color: {
        if (root.isSelected) {
            return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
        }
        return isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    }
    border.width: root.isSelected ? 1.5 : 1

    Behavior on color {
        ColorAnimation { duration: 120 }
    }
    Behavior on border.color {
        ColorAnimation { duration: 120 }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 10

        // Transport Icon Indicator
        Rectangle {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: root.isSkyx ? (root.isOutdoor ? Qt.rgba(0, 146/255, 168/255, 0.12) : Qt.rgba(47/255, 208/255, 232/255, 0.14))
                               : (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : Qt.rgba(140/255, 163/255, 184/255, 0.12))

            QGCColoredImage {
                anchors.centerIn: parent
                width: 16
                height: 16
                sourceSize.width: 16
                sourceSize.height: 16
                fillMode: Image.PreserveAspectFit
                source: {
                    if (root.transportType === "ble" || root.transportType === "bluetooth") {
                        return "/InstrumentValueIcons/bluetooth.svg"
                    }
                    if (root.transportType === "wifi" || root.transportType === "udp" || root.transportType === "tcp") {
                        return "/qmlimages/wifi.svg"
                    }
                    if (root.transportType === "serial" || root.transportType === "usb") {
                        return "/InstrumentValueIcons/usb.svg"
                    }
                    return "/InstrumentValueIcons/airplane.svg"
                }
                color: root.isSkyx ? (root.isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent)
                                   : (root.isOutdoor ? PulseGCSTokens.outdoorTextMuted : PulseGCSTokens.textMuted)
            }
        }

        // Details column
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    id: nameLabel
                    Layout.maximumWidth: parent.width - (idBadge.visible ? idBadge.width + 6 : 0)
                    text: root.deviceName.length > 0 ? root.deviceName : qsTr("Unknown Device")
                    font.pixelSize: 13
                    font.bold: true
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }

                PulseGCSIdentityBadge {
                    id: idBadge
                    visible: root.showIdentityBadge
                    isSkyx: root.isSkyx
                    compact: true
                    isOutdoor: root.isOutdoor
                }

                Item { Layout.fillWidth: true }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: {
                        if (root.subtitleText.length > 0) return root.subtitleText
                        if (root.deviceAddress.length > 0) return root.deviceAddress
                        return ""
                    }
                    visible: text.length > 0
                    font.pixelSize: 11
                    color: PulseGCSTokens.metaText(root.isOutdoor)
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }

                PulseGCSSignalIndicator {
                    visible: root.showSignal && (root.rssi !== 0 || root.signalLevel >= 0)
                    rssi: root.rssi
                    signalLevel: root.signalLevel
                    showText: false
                    isOutdoor: root.isOutdoor
                }

                Item { Layout.fillWidth: true }
            }
        }

        // Status pill if present
        PulseGCSStatusPill {
            visible: root.status.length > 0
            status: root.status
            text: root.statusText
            pulsing: root.statusPulsing
            isOutdoor: root.isOutdoor
        }

        // Secondary Action Button (e.g. Unpair, Info)
        Button {
            id: secondaryBtn
            visible: root.secondaryActionText.length > 0
            text: root.secondaryActionText
            enabled: root.secondaryActionEnabled
            implicitHeight: 30
            font.pixelSize: 11
            font.bold: true

            contentItem: Text {
                text: secondaryBtn.text
                font: secondaryBtn.font
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: 6
                color: secondaryBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                            : (secondaryBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface)
                                                                    : (root.isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel))
                border.color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
                border.width: 1
            }

            onClicked: root.secondaryActionClicked()
        }

        // Primary Action Button (e.g. Connect, Pair, Disconnect)
        Button {
            id: primaryBtn
            visible: root.primaryActionText.length > 0
            text: root.primaryActionText
            enabled: root.primaryActionEnabled
            implicitHeight: 30
            font.pixelSize: 11
            font.bold: true

            contentItem: Text {
                text: primaryBtn.text
                font: primaryBtn.font
                color: {
                    if (root.primaryActionIsDanger) return "#FFFFFF"
                    if (root.isSkyx) return root.isOutdoor ? "#FFFFFF" : "#04222B"
                    return root.isOutdoor ? "#FFFFFF" : PulseGCSTokens.primaryText(root.isOutdoor)
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: 6
                color: {
                    if (root.primaryActionIsDanger) {
                        return root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                    }
                    if (root.isSkyx) {
                        return primaryBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorAccentHover : PulseGCSTokens.accentHover)
                                                  : (root.isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent)
                    }
                    return primaryBtn.pressed ? (root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                              : (primaryBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorAccentHover : PulseGCSTokens.surfaceElevated)
                                                                    : (root.isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.buttonSurface))
                }
                border.color: {
                    if (root.primaryActionIsDanger || root.isSkyx) return "transparent"
                    return root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
                }
                border.width: (root.primaryActionIsDanger || root.isSkyx) ? 0 : 1
            }

            onClicked: root.primaryActionClicked()
        }
    }
}
