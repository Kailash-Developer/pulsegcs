import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QGroundControl
import PulseGCS

Rectangle {
    id: root

    property string title: ""
    property string subtitle: ""
    property string status: ""
    property string statusText: ""
    property bool statusPulsing: false
    property bool showIdentityBadge: false
    property bool isSkyx: true
    property bool accentTint: false
    property real contentPadding: 14
    property bool isOutdoor: PulseGCSTokens.isOutdoor

    default property alias content: contentSlot.children
    property alias footer: footerSlot.children

    implicitWidth: 360
    implicitHeight: mainLayout.implicitHeight + (contentPadding * 2)

    radius: PulseGCSTokens.radiusCard

    color: {
        if (accentTint) {
            return isOutdoor ? PulseGCSTokens.outdoorCardTint : PulseGCSTokens.cardTint
        }
        return isOutdoor ? PulseGCSTokens.outdoorWindow : PulseGCSTokens.surfacePanel
    }

    border.color: {
        if (accentTint) {
            return isOutdoor ? Qt.rgba(0, 146/255, 168/255, 0.28) : Qt.rgba(47/255, 208/255, 232/255, 0.25)
        }
        return isOutdoor ? PulseGCSTokens.outdoorWindowShadeDark : PulseGCSTokens.buttonBorder
    }
    border.width: 1

    ColumnLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.contentPadding
        spacing: 12

        // Header row
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            visible: root.title.length > 0 || root.subtitle.length > 0 || root.status.length > 0 || root.showIdentityBadge
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    id: titleText
                    visible: root.title.length > 0
                    Layout.fillWidth: true
                    text: root.title
                    font.pixelSize: 13
                    font.bold: true
                    font.letterSpacing: 0.2
                    color: PulseGCSTokens.primaryText(root.isOutdoor)
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }

                Text {
                    id: subtitleText
                    visible: root.subtitle.length > 0
                    Layout.fillWidth: true
                    text: root.subtitle
                    font.pixelSize: 11
                    color: PulseGCSTokens.mutedText(root.isOutdoor)
                    elide: Text.ElideRight
                    renderType: Text.QtRendering
                }
            }

            // Optional SkyX identity badge
            PulseGCSIdentityBadge {
                id: idBadge
                visible: root.showIdentityBadge
                isSkyx: root.isSkyx
                compact: true
                isOutdoor: root.isOutdoor
            }

            // Optional Status pill
            PulseGCSStatusPill {
                id: pill
                visible: root.status.length > 0
                status: root.status
                text: root.statusText
                pulsing: root.statusPulsing
                isOutdoor: root.isOutdoor
            }
        }

        // Custom content slot
        Item {
            id: contentContainer
            Layout.fillWidth: true
            implicitHeight: contentSlot.childrenRect.height
            visible: contentSlot.children.length > 0

            Item {
                id: contentSlot
                anchors.fill: parent
            }
        }

        // Custom footer / action buttons slot
        Item {
            id: footerContainer
            Layout.fillWidth: true
            implicitHeight: footerSlot.childrenRect.height
            visible: footerSlot.children.length > 0

            Item {
                id: footerSlot
                anchors.fill: parent
            }
        }
    }
}
