import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    // Severity: "blocking" (err), "warning" (warn), "info" (neutral/accent)
    property string severity: "warning"
    property string title: ""
    property string description: ""
    property string actionText: ""
    property bool actionEnabled: true
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    signal actionClicked()

    implicitWidth: 380
    implicitHeight: Math.max(68, contentLayout.implicitHeight + 20)
    radius: 8

    color: isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfaceElevated
    border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    border.width: 1

    // 3.5px Colored Left Border Accent Indicator
    Rectangle {
        id: leftBorderStripe
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 4
        radius: 2

        color: {
            if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
            }
            if (root.severity === "warning" || root.severity === "warn" || root.severity === "degraded") {
                return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
            }
            return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
        }
    }

    RowLayout {
        id: contentLayout
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 10

        // Info details
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                // Severity Badge
                Rectangle {
                    implicitHeight: 18
                    implicitWidth: sevText.implicitWidth + 10
                    radius: 4

                    color: {
                        if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                            return isOutdoor ? PulseGCSTokens.outdoorErrBg : PulseGCSTokens.errBg
                        }
                        if (root.severity === "warning" || root.severity === "warn" || root.severity === "degraded") {
                            return isOutdoor ? PulseGCSTokens.outdoorWarnBg : PulseGCSTokens.warnBg
                        }
                        return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
                    }

                    border.color: {
                        if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                            return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                        }
                        if (root.severity === "warning" || root.severity === "warn" || root.severity === "degraded") {
                            return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                        }
                        return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
                    }
                    border.width: 1

                    Text {
                        id: sevText
                        anchors.centerIn: parent
                        text: {
                            if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                                return qsTr("BLOCKING")
                            }
                            if (root.severity === "warning" || root.severity === "warn" || root.severity === "degraded") {
                                return qsTr("WARNING")
                            }
                            return qsTr("INFO")
                        }
                        font.pixelSize: 9
                        font.bold: true
                        color: {
                            if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                                return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                            }
                            if (root.severity === "warning" || root.severity === "warn" || root.severity === "degraded") {
                                return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                            }
                            return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
                        }
                        renderType: Text.QtRendering
                    }
                }

                // Issue Title
                Text {
                    text: root.title
                    font.pixelSize: 12
                    font.bold: true
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    renderType: Text.QtRendering
                }
            }

            // Description / Actionable Reason
            Text {
                visible: root.description.length > 0
                text: root.description
                font.pixelSize: 11
                color: PulseGCSTokens.metaText(root.isOutdoor)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                renderType: Text.QtRendering
            }
        }

        // Action Button
        Button {
            id: actionBtn
            visible: root.actionText.length > 0
            text: root.actionText
            enabled: root.actionEnabled
            implicitHeight: 28
            font.pixelSize: 10
            font.bold: true

            contentItem: Text {
                text: actionBtn.text
                font: actionBtn.font
                color: {
                    if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                        return "#FFFFFF"
                    }
                    return isOutdoor ? "#FFFFFF" : PulseGCSTokens.primaryText(root.isOutdoor)
                }
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: 5
                color: {
                    if (root.severity === "blocking" || root.severity === "critical" || root.severity === "error" || root.severity === "err") {
                        return actionBtn.hovered ? (root.isOutdoor ? Qt.darker(PulseGCSTokens.outdoorErr, 1.1) : Qt.lighter(PulseGCSTokens.err, 1.1))
                                                 : (root.isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err)
                    }
                    return actionBtn.hovered ? (root.isOutdoor ? PulseGCSTokens.outdoorAccentHover : PulseGCSTokens.accentHover)
                                             : (root.isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.surfacePanel)
                }
                border.color: (root.severity === "blocking" || isOutdoor) ? "transparent" : PulseGCSTokens.buttonBorder
                border.width: (root.severity === "blocking" || isOutdoor) ? 0 : 1
            }

            onClicked: root.actionClicked()
        }
    }
}
