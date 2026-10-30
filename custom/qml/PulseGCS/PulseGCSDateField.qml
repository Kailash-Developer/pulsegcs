import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import PulseGCS

Item {
    id: root

    property string text: ""
    property bool isOutdoor: false
    property alias dayText: dayField.text
    property alias monthText: monthField.text
    property alias yearText: yearField.text

    property var nextTabItem: null
    property var previousTabItem: null
    property alias firstFocusItem: dayField
    property alias lastFocusItem: yearField

    activeFocusOnTab: true
    onActiveFocusChanged: {
        if (activeFocus) {
            dayField.forceActiveFocus()
            dayField.selectAll()
        }
    }

    function forceActiveFocus() {
        dayField.forceActiveFocus()
        dayField.selectAll()
    }

    function clear() {
        _syncing = true
        dayField.text = ""
        monthField.text = ""
        yearField.text = ""
        root.text = ""
        _syncing = false
    }

    implicitWidth: 280
    implicitHeight: 34

    readonly property color textColor: PulseGCSTokens.primaryText(root.isOutdoor)
    readonly property color metaColor: PulseGCSTokens.metaText(root.isOutdoor)
    readonly property color borderColor: (dayField.activeFocus || monthField.activeFocus || yearField.activeFocus)
                                          ? PulseGCSTokens.accentColor(root.isOutdoor)
                                          : PulseGCSTokens.subtleBorder(root.isOutdoor)

    property bool _syncing: false

    // Synchronize external text to internal segments
    onTextChanged: {
        if (_syncing) return
        _syncing = true
        if (!text || text.trim().length === 0) {
            dayField.text = ""
            monthField.text = ""
            yearField.text = ""
            _syncing = false
            return
        }
        var trimmed = text.trim()
        var dmyMatch = trimmed.match(/^(\d{1,2})[\s\/\-\.]+(\d{1,2})[\s\/\-\.]+(\d{4})$/)
        var isoMatch = trimmed.match(/^(\d{4})[\s\/\-\.]+(\d{1,2})[\s\/\-\.]+(\d{1,2})$/)

        var d = dmyMatch ? dmyMatch[1] : (isoMatch ? isoMatch[3] : "")
        var m = dmyMatch ? dmyMatch[2] : (isoMatch ? isoMatch[2] : "")
        var y = dmyMatch ? dmyMatch[3] : (isoMatch ? isoMatch[1] : "")

        if (d && d !== dayField.text) dayField.text = (d.length === 1 ? "0" + d : d)
        if (m && m !== monthField.text) monthField.text = (m.length === 1 ? "0" + m : m)
        if (y && y !== yearField.text) yearField.text = y
        _syncing = false
    }

    function updateExternalText() {
        if (_syncing) return
        _syncing = true
        var d = dayField.text.trim()
        var m = monthField.text.trim()
        var y = yearField.text.trim()
        if (d.length === 0 && m.length === 0 && y.length === 0) {
            root.text = ""
        } else {
            root.text = (d.length === 1 ? "0" + d : d) + " / " + (m.length === 1 ? "0" + m : m) + " / " + y
        }
        _syncing = false
    }

    // Outer Container
    Rectangle {
        id: containerRect
        anchors.fill: parent
        radius: PulseGCSTokens.radiusControl
        color: root.isOutdoor ? PulseGCSTokens.outdoorWindowShadeLight : PulseGCSTokens.buttonSurface
        border.color: root.borderColor
        border.width: (dayField.activeFocus || monthField.activeFocus || yearField.activeFocus) ? 1.5 : 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 4

            // --- Day Field (DD: 01 - 31) ---
            TextInput {
                id: dayField
                Layout.preferredWidth: 26
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 2
                inputMethodHints: Qt.ImhDigitsOnly
                renderType: Text.QtRendering
                validator: RegularExpressionValidator { regularExpression: /^(0?[1-9]|[12]\d|3[01])?$/ }
                activeFocusOnTab: true
                KeyNavigation.tab: monthField
                KeyNavigation.backtab: root.previousTabItem

                Text {
                    anchors.centerIn: parent
                    text: "DD"
                    font.family: dayField.font.family
                    font.pixelSize: 11
                    color: root.metaColor
                    visible: dayField.text.length === 0 && !dayField.activeFocus
                    renderType: Text.QtRendering
                }

                onTextChanged: {
                    if (text.length === 2) {
                        monthField.forceActiveFocus()
                        monthField.selectAll()
                    } else if (text.length === 1 && parseInt(text, 10) >= 4) {
                        text = "0" + text
                        monthField.forceActiveFocus()
                        monthField.selectAll()
                    }
                    root.updateExternalText()
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Slash || event.key === Qt.Key_Right) {
                        monthField.forceActiveFocus()
                        monthField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        monthField.forceActiveFocus()
                        monthField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backtab) {
                        if (root.previousTabItem && typeof root.previousTabItem.forceActiveFocus === "function") {
                            root.previousTabItem.forceActiveFocus()
                            event.accepted = true
                        }
                    }
                }
            }

            Text {
                text: "/"
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: root.metaColor
                renderType: Text.QtRendering
            }

            // --- Month Field (MM: 01 - 12) ---
            TextInput {
                id: monthField
                Layout.preferredWidth: 26
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 2
                inputMethodHints: Qt.ImhDigitsOnly
                renderType: Text.QtRendering
                validator: RegularExpressionValidator { regularExpression: /^(0?[1-9]|1[0-2])?$/ }
                activeFocusOnTab: true
                KeyNavigation.tab: yearField
                KeyNavigation.backtab: dayField

                Text {
                    anchors.centerIn: parent
                    text: "MM"
                    font.family: monthField.font.family
                    font.pixelSize: 11
                    color: root.metaColor
                    visible: monthField.text.length === 0 && !monthField.activeFocus
                    renderType: Text.QtRendering
                }

                onTextChanged: {
                    if (text.length === 2) {
                        yearField.forceActiveFocus()
                        yearField.selectAll()
                    } else if (text.length === 1 && parseInt(text, 10) >= 2) {
                        text = "0" + text
                        yearField.forceActiveFocus()
                        yearField.selectAll()
                    }
                    root.updateExternalText()
                }

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Slash || event.key === Qt.Key_Right) {
                        yearField.forceActiveFocus()
                        yearField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Tab) {
                        yearField.forceActiveFocus()
                        yearField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backtab) {
                        dayField.forceActiveFocus()
                        dayField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backspace && text.length === 0) {
                        dayField.forceActiveFocus()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left && cursorPosition === 0) {
                        dayField.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }

            Text {
                text: "/"
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                color: root.metaColor
                renderType: Text.QtRendering
            }

            // --- Year Field (YYYY: 4 digits) ---
            TextInput {
                id: yearField
                Layout.preferredWidth: 44
                font.family: ScreenTools.normalFontFamily
                font.pixelSize: 12
                font.bold: true
                color: root.textColor
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                maximumLength: 4
                inputMethodHints: Qt.ImhDigitsOnly
                renderType: Text.QtRendering
                validator: RegularExpressionValidator { regularExpression: /^\d{0,4}$/ }
                activeFocusOnTab: true
                KeyNavigation.tab: root.nextTabItem
                KeyNavigation.backtab: monthField

                Text {
                    anchors.centerIn: parent
                    text: "YYYY"
                    font.family: yearField.font.family
                    font.pixelSize: 11
                    color: root.metaColor
                    visible: yearField.text.length === 0 && !yearField.activeFocus
                    renderType: Text.QtRendering
                }

                onTextChanged: root.updateExternalText()

                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab) {
                        if (root.nextTabItem && typeof root.nextTabItem.forceActiveFocus === "function") {
                            root.nextTabItem.forceActiveFocus()
                            event.accepted = true
                        }
                    } else if (event.key === Qt.Key_Backtab) {
                        monthField.forceActiveFocus()
                        monthField.selectAll()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backspace && text.length === 0) {
                        monthField.forceActiveFocus()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left && cursorPosition === 0) {
                        monthField.forceActiveFocus()
                        event.accepted = true
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
