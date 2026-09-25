import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property string name: ""
    property string status: "ok" // ok, err, warn, checking, neutral
    property string valueText: ""
    property string detailText: ""
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    implicitWidth: 380
    implicitHeight: Math.max(40, rowLayout.implicitHeight + 12)
    radius: 6

    color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfaceElevated
    border.color: isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    border.width: 1

    RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 10

        // 22x22 Status Icon Circle
        Rectangle {
            id: checkBadge
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            radius: 11

            color: {
                if (root.status === "ok" || root.status === "pass" || root.status === "ready") {
                    return isOutdoor ? PulseGCSTokens.outdoorOkBg : PulseGCSTokens.okBg
                }
                if (root.status === "err" || root.status === "error" || root.status === "fail") {
                    return isOutdoor ? PulseGCSTokens.outdoorErrBg : PulseGCSTokens.errBg
                }
                if (root.status === "warn" || root.status === "warning") {
                    return isOutdoor ? PulseGCSTokens.outdoorWarnBg : PulseGCSTokens.warnBg
                }
                if (root.status === "checking") {
                    return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
                }
                return isOutdoor ? PulseGCSTokens.outdoorNeutralBg : PulseGCSTokens.neutralBg
            }

            border.color: {
                if (root.status === "ok" || root.status === "pass" || root.status === "ready") {
                    return isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok
                }
                if (root.status === "err" || root.status === "error" || root.status === "fail") {
                    return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                }
                if (root.status === "warn" || root.status === "warning") {
                    return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                }
                if (root.status === "checking") {
                    return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
                }
                return isOutdoor ? PulseGCSTokens.outdoorNeutral : PulseGCSTokens.neutral
            }
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                text: {
                    if (root.status === "ok" || root.status === "pass" || root.status === "ready") return "✓"
                    if (root.status === "err" || root.status === "error" || root.status === "fail") return "✕"
                    if (root.status === "warn" || root.status === "warning") return "!"
                    if (root.status === "checking") return "…"
                    return "?"
                }
                font.pixelSize: 11
                font.bold: true
                color: checkBadge.border.color
                renderType: Text.QtRendering
            }
        }

        // Title and detail
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: root.name
                font.pixelSize: 12
                font.bold: true
                color: PulseGCSTokens.primaryText(root.isOutdoor)
                elide: Text.ElideRight
                Layout.fillWidth: true
                renderType: Text.QtRendering
            }

            Text {
                visible: root.detailText.length > 0
                text: root.detailText
                font.pixelSize: 10
                color: {
                    if (root.status === "err" || root.status === "fail") {
                        return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
                    }
                    if (root.status === "warn") {
                        return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
                    }
                    return PulseGCSTokens.metaText(root.isOutdoor)
                }
                elide: Text.ElideRight
                Layout.fillWidth: true
                renderType: Text.QtRendering
            }
        }

        // Value text on right
        Text {
            visible: root.valueText.length > 0
            text: root.valueText
            font.pixelSize: 11
            font.weight: Font.Medium
            color: PulseGCSTokens.mutedText(root.isOutdoor)
            horizontalAlignment: Text.AlignRight
            renderType: Text.QtRendering
        }
    }
}
