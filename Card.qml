/* Yatagarasu — Card.qml
 *
 * The Kasugai scroll, seated as a Ryoku notification card.
 *
 * One scroll per message, as she always carried them: a dark
 * glass plate, a lit priority edge on the left, the message in
 * mono, and the burn along the foot — the scroll's remaining
 * life, spent while it waits. A CRITICAL scroll does not burn;
 * it waits, shivering faintly, for the captain's hand. The ✕
 * is the acknowledgment. The crow stands on the card's bottom
 * border — the burn is her wire, prism-lit along the foot, and
 * she perches at its end (v1.1, the captain's ruling: the bird
 * and the bottom border she perches upon belong to this plugin).
 *
 * Priority themes are hers, from the Form Eighty: LOW cyan,
 * MEDIUM emerald, HIGH amber, CRITICAL rose. The freedesktop
 * urgency maps low→LOW, normal→MEDIUM, critical→CRITICAL.
 *
 * The host owns the window, the column, the timers of record,
 * the sounds and the history. This card owns only its face.
 */
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import shell.services

Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    readonly property int _urg: {
        const u = root.notification ? root.notification.urgency : 1
        return (u !== undefined && u !== null) ? u : 1
    }
    readonly property string _prio: _urg >= 2 ? "CRITICAL"
                                  : _urg <= 0 ? "LOW" : "MEDIUM"
    readonly property color _theme: _prio === "CRITICAL" ? "#F43F5E"
                                  : _prio === "HIGH"     ? "#F5B300"
                                  : _prio === "LOW"      ? "#22D3EE"
                                                         : "#10D9A3"
    readonly property string _mono: "monospace"

    property real _bornAt: 0
    property real _elapsed: 0
    property string _stamp: ""
    readonly property real _life: {
        if (root._prio === "CRITICAL" || root.lifespanMs <= 0) return 1.0
        const f = 1.0 - (root._elapsed / root.lifespanMs)
        return f < 0 ? 0 : f
    }

    Component.onCompleted: {
        root._bornAt = Date.now()
        root._stamp = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    }
    Component.onDestruction: _burnTimer.stop()

    Timer {
        id: _burnTimer
        interval: 100
        repeat: true
        running: root.lifespanMs > 0 && root._prio !== "CRITICAL"
        onTriggered: root._elapsed = Date.now() - root._bornAt
    }

    readonly property var visibleActions: {
        const source = root.notification?.actions || []
        const result = []
        for (let i = 0; i < source.length; ++i) {
            const candidate = source[i]
            if (candidate && candidate.identifier !== "default"
                    && String(candidate.text || "").length > 0)
                result.push(candidate)
        }
        return result
    }
    readonly property var defaultAction: {
        const source = root.notification?.actions || []
        for (let i = 0; i < source.length; ++i) {
            if (source[i] && source[i].identifier === "default")
                return source[i]
        }
        return null
    }

    function invokeAndDismiss(action): void {
        if (action && typeof action.invoke === "function")
            action.invoke()
        Notifs.dismiss(root.notification)
    }

    implicitHeight: _plate.height

    // The critical glitch — a 1px shiver, her intel-shake.
    property real _glitchX: 0
    SequentialAnimation on _glitchX {
        running: root._prio === "CRITICAL"
        loops: Animation.Infinite
        NumberAnimation { to: -1; duration: 90 }
        NumberAnimation { to: 1;  duration: 90 }
        NumberAnimation { to: 0;  duration: 220 }
        PauseAnimation { duration: 1600 }
    }

    Rectangle {
        id: _plate
        x: root._glitchX
        width: parent.width
        height: _col.implicitHeight + 20 * root.us
        radius: 6
        color: Qt.rgba(0.02, 0.04, 0.07, 0.88)
        border.color: Qt.alpha(root._theme, 0.55)
        border.width: 1

        // Priority edge — a lit spine of her own, on the left.
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: 2
            radius: 1
            color: root._theme
            opacity: 0.85
        }

        Column {
            id: _col
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.leftMargin: 12 * root.us
            anchors.rightMargin: 14 * root.us
            anchors.topMargin: 9 * root.us
            spacing: 4

            Row {
                width: parent.width
                spacing: 7

                Text {
                    text: "◈"
                    color: root._theme
                    font.pixelSize: 15 * root.us
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    width: parent.width - 110 * root.us
                    text: root.notification ? (root.notification.summary || "") : ""
                    color: Qt.rgba(1, 1, 1, 0.94)
                    font.family: root._mono
                    font.pixelSize: 13 * root.us
                    font.bold: true
                    font.letterSpacing: 0.6
                    elide: Text.ElideRight
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: root._prio
                    color: root._theme
                    font.family: root._mono
                    font.pixelSize: 9 * root.us
                    font.letterSpacing: 1.2
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "✕"
                    color: _ackHover.hovered ? "#ffffff" : Qt.rgba(1, 1, 1, 0.45)
                    font.pixelSize: 12 * root.us
                    anchors.verticalCenter: parent.verticalCenter
                    HoverHandler { id: _ackHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: Notifs.dismiss(root.notification)
                    }
                }
            }

            Text {
                width: parent.width - 58 * root.us
                visible: text.length > 0
                text: root.notification ? (root.notification.body || "") : ""
                color: Qt.rgba(1, 1, 1, 0.78)
                font.family: root._mono
                font.pixelSize: 12 * root.us
                lineHeight: 1.25
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                maximumLineCount: 3
                elide: Text.ElideRight
            }

            Row {
                spacing: 8
                Text {
                    text: root._stamp
                    color: Qt.rgba(1, 1, 1, 0.35)
                    font.family: root._mono
                    font.pixelSize: 9 * root.us
                }
                Text {
                    text: root.notification ? String(root.notification.appName || "").toUpperCase() : ""
                    color: Qt.alpha(root._theme, 0.75)
                    font.family: root._mono
                    font.pixelSize: 9 * root.us
                    font.letterSpacing: 1
                }
                Text {
                    visible: root._prio === "CRITICAL"
                    text: "ACK REQUIRED"
                    color: "#F43F5E"
                    font.family: root._mono
                    font.pixelSize: 9 * root.us
                    font.letterSpacing: 1
                }
            }

            Row {
                spacing: 8
                visible: root.visibleActions.length > 0
                Repeater {
                    model: root.visibleActions
                    delegate: Rectangle {
                        required property var modelData
                        width: _actText.implicitWidth + 14 * root.us
                        height: 20 * root.us
                        radius: 4
                        color: _actHover.hovered ? Qt.alpha(root._theme, 0.25)
                                                 : Qt.alpha(root._theme, 0.12)
                        border.width: 1
                        border.color: Qt.alpha(root._theme, 0.45)
                        Text {
                            id: _actText
                            anchors.centerIn: parent
                            text: parent.modelData.text || ""
                            color: Qt.rgba(1, 1, 1, 0.9)
                            font.family: root._mono
                            font.pixelSize: 10 * root.us
                        }
                        HoverHandler { id: _actHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: root.invokeAndDismiss(parent.modelData)
                        }
                    }
                }
            }
        }

        // Her wire — the card's bottom border, prism-lit in the
        // priority's color. It is always there at rest; the burn
        // spends along it. A CRITICAL scroll does not burn.
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 1
            width: parent.width
            color: root._theme
            opacity: 0.35
        }
        Rectangle {
            anchors { left: parent.left; bottom: parent.bottom }
            height: 2
            width: parent.width * root._life
            color: root._theme
            opacity: root._prio === "CRITICAL" ? 0.9 : 0.55
        }

        // The crow, standing on the wire at the foot's end; her
        // eye takes the priority's mood. She is drawn at 128x116
        // in her own file; the perch scales her down whole, feet
        // on the bottom border, unclipped — she stands ON the
        // card, not in it.
        Item {
            anchors { right: parent.right; bottom: parent.bottom }
            width: 64 * root.us
            height: 58 * root.us
            KasugaiCrow {
                width: 128
                height: 116
                scale: 0.5 * root.us
                transformOrigin: Item.TopLeft
                mood: root._prio === "CRITICAL" ? "CRITICAL"
                     : root._prio === "HIGH" ? "HIGH" : ""
                opacity: 0.95
            }
        }

        // Clicking the plate runs the sender's default action.
        TapHandler {
            onTapped: if (root.defaultAction) root.invokeAndDismiss(root.defaultAction)
        }
    }
}
