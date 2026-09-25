import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property string noticeType: "info" // info, warn, err, success
    property string message: ""
    property string actionText: ""
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    signal actionClicked()

    implicitWidth: 380
    implicitHeight: Math.max(34, contentRow.implicitHeight + 12)
    radius: 6

    color: {
        if (root.noticeType === "warn" || root.noticeType === "warning") {
            return isOutdoor ? PulseGCSTokens.outdoorWarnBg : PulseGCSTokens.warnBg
        }
        if (root.noticeType === "err" || root.noticeType === "error") {
            return isOutdoor ? PulseGCSTokens.outdoorErrBg : PulseGCSTokens.errBg
        }
        if (root.noticeType === "success" || root.noticeType === "ok") {
            return isOutdoor ? PulseGCSTokens.outdoorOkBg : PulseGCSTokens.okBg
        }
        return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
    }

    border.color: {
        if (root.noticeType === "warn" || root.noticeType === "warning") {
            return isOutdoor ? PulseGCSTokens.outdoorWarn : PulseGCSTokens.warn
        }
        if (root.noticeType === "err" || root.noticeType === "error") {
            return isOutdoor ? PulseGCSTokens.outdoorErr : PulseGCSTokens.err
        }
        if (root.noticeType === "success" || root.noticeType === "ok") {
            return isOutdoor ? PulseGCSTokens.outdoorOk : PulseGCSTokens.ok
        }
        return isOutdoor ? PulseGCSTokens.outdoorAccent : PulseGCSTokens.accent
    }
    border.width: 1

    RowLayout {
        id: contentRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 6
        anchors.bottomMargin: 6
        spacing: 8

        Text {
            text: {
                if (root.noticeType === "warn" || root.noticeType === "warning") return "⚠"
                if (root.noticeType === "err" || root.noticeType === "error") return "⛔"
                if (root.noticeType === "success" || root.noticeType === "ok") return "✓"
                return "ℹ"
            }
            font.pixelSize: 12
            color: root.border.color
            renderType: Text.QtRendering
        }

        Text {
            text: root.message
            font.pixelSize: 11
            font.bold: true
            color: PulseGCSTokens.primaryText(root.isOutdoor)
            elide: Text.ElideRight
            Layout.fillWidth: true
            renderType: Text.QtRendering
        }

        Button {
            id: actionBtn
            visible: root.actionText.length > 0
            text: root.actionText
            implicitHeight: 22
            font.pixelSize: 10
            font.bold: true

            contentItem: Text {
                text: actionBtn.text
                font: actionBtn.font
                color: root.border.color
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                renderType: Text.QtRendering
            }

            background: Rectangle {
                radius: 4
                color: actionBtn.pressed ? (isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.surfaceElevated)
                                         : (actionBtn.hovered ? (isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.surfacePanel)
                                                              : "transparent")
                border.color: root.border.color
                border.width: 1
            }

            onClicked: root.actionClicked()
        }
    }
}
