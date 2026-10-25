import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell.Services.Notifications
import shell.services
import Ryoku.Ui.Singletons

Item {
    id: card

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    readonly property var visibleActions: {
        const all = card.notification && card.notification.actions
            ? card.notification.actions : [];
        const result = [];
        for (let index = 0; index < all.length; ++index) {
            const action = all[index];
            if (action && action.identifier !== "default"
                    && String(action.text || "").trim().length > 0)
                result.push(action);
        }
        return result;
    }
    readonly property var defaultAction: {
        const all = card.notification && card.notification.actions
            ? card.notification.actions : [];
        for (let index = 0; index < all.length; ++index) {
            if (all[index] && all[index].identifier === "default")
                return all[index];
        }
        return null;
    }
    readonly property string appName: String(card.notification?.appName || "Notification")
    readonly property string appInitial: card.appName.trim().length > 0
        ? card.appName.trim().charAt(0).toUpperCase() : "?"
    readonly property string noticeImage: card.showImages
        ? String(card.notification?.image || "") : ""
    readonly property string appIconSource: String(card.notification?.appIcon || "").length > 0
        ? String(Icons.path(card.notification.appIcon, true)) : ""
    readonly property string sealSource: card.noticeImage.length > 0
        ? card.noticeImage : card.appIconSource
    readonly property bool sealShowsNotice: card.noticeImage.length > 0
    readonly property bool critical: card.notification
        && card.notification.urgency === NotificationUrgency.Critical

    property real lifeRemaining: 1

    implicitHeight: sheet.implicitHeight

    function invoke(action) {
        if (!action || typeof action.invoke !== "function")
            return;
        action.invoke();
        Notifs.dismiss(card.notification);
    }

    NumberAnimation on lifeRemaining {
        running: card.lifespanMs > 0
        from: 1
        to: 0
        duration: Math.max(1, card.lifespanMs)
        easing.type: Easing.Linear
    }

    Rectangle {
        id: sheet

        width: card.width
        height: implicitHeight
        implicitHeight: content.implicitHeight + Tokens.s4 * 2 * card.us
        radius: Tokens.radius * card.us
        color: Tokens.paperLift
        border.width: Tokens.border * card.us
        border.color: Tokens.lineStrong
        clip: true

        Column {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.s4 * card.us
            spacing: Tokens.s3 * card.us

            Item {
                id: heading

                width: parent.width
                height: Math.max(appLabel.implicitHeight, timeLabel.implicitHeight,
                    closeButton.height)

                Text {
                    id: appLabel

                    anchors.left: parent.left
                    anchors.right: timeLabel.left
                    anchors.rightMargin: Tokens.s2 * card.us
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.appName.toUpperCase()
                    color: Tokens.inkDim
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fMicro * card.us
                    font.letterSpacing: Tokens.trackLabel
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    id: timeLabel

                    anchors.right: closeButton.left
                    anchors.rightMargin: Tokens.s2 * card.us
                    anchors.verticalCenter: parent.verticalCenter
                    text: Notifs.timeLabel(card.notification)
                    color: Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny * card.us
                    font.letterSpacing: Tokens.trackLabel
                }

                Item {
                    id: closeButton

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.s5 * card.us
                    height: width
                    opacity: cardHover.hovered ? 1 : 0
                    enabled: opacity > 0

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: closeHit.containsMouse ? Tokens.tint10 : "transparent"
                        border.width: Tokens.border * card.us
                        border.color: closeHit.containsMouse ? Tokens.lineStrong : Tokens.lineSoft
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Tokens.inkDim
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fBody * card.us
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: closeHit

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notifs.dismiss(card.notification)
                    }

                    Behavior on opacity {
                        NumberAnimation { duration: Tokens.dur(100) }
                    }
                }
            }

            Item {
                id: message

                width: parent.width
                height: Math.max(seal.height, letterCopy.implicitHeight)

                MouseArea {
                    anchors.fill: parent
                    enabled: card.defaultAction !== null
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: card.invoke(card.defaultAction)
                }

                Rectangle {
                    id: seal

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.s7 * card.us
                    height: width
                    radius: width / 2
                    color: Tokens.paper
                    border.width: Tokens.border * card.us
                    border.color: Tokens.lineStrong

                    Image {
                        id: sealMedia

                        anchors.fill: parent
                        anchors.margins: card.sealShowsNotice ? 0 : Tokens.s2 * card.us
                        source: card.sealSource
                        sourceSize.width: Math.ceil(width * 2)
                        sourceSize.height: Math.ceil(height * 2)
                        fillMode: card.sealShowsNotice
                            ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: false
                    }

                    OpacityMask {
                        anchors.fill: sealMedia
                        source: sealMedia
                        maskSource: Rectangle {
                            width: sealMedia.width
                            height: sealMedia.height
                            radius: width / 2
                        }
                        visible: sealMedia.status === Image.Ready
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: sealMedia.status !== Image.Ready
                        text: card.appInitial
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: Tokens.fValue * card.us
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    id: letterCopy

                    anchors.left: seal.right
                    anchors.right: parent.right
                    anchors.leftMargin: Tokens.s3 * card.us
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s1 * card.us

                    Text {
                        width: parent.width
                        text: String(card.notification?.summary || "Notification")
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: Tokens.fRow * card.us
                        font.weight: Font.DemiBold
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: String(card.notification?.body || "")
                        textFormat: Text.StyledText
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * card.us
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }

            Item {
                id: actionStrip

                width: parent.width
                height: visible ? Tokens.ctlH * card.us : 0
                visible: card.visibleActions.length > 0

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Tokens.border * card.us
                    color: Tokens.line
                }

                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Tokens.border * card.us

                    Repeater {
                        model: card.visibleActions

                        delegate: Item {
                            id: actionButton

                            required property var modelData
                            required property int index

                            width: actionStrip.width / card.visibleActions.length
                            height: actionStrip.height - Tokens.border * card.us

                            Rectangle {
                                anchors.fill: parent
                                color: actionHit.containsMouse ? Tokens.tint5 : "transparent"
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: Tokens.border * card.us
                                color: Tokens.line
                                visible: actionButton.index > 0
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Tokens.s2 * card.us
                                text: String(actionButton.modelData.text || "")
                                color: Tokens.inkDim
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall * card.us
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                id: actionHit

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: card.invoke(actionButton.modelData)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: card.critical
            x: card.position === "Left" ? 0 : parent.width - width
            width: Math.max(1, Tokens.border * card.us)
            height: parent.height
            color: Tokens.alert
        }

        Rectangle {
            visible: card.lifespanMs > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width * card.lifeRemaining
            height: Math.max(1, Tokens.border * card.us)
            color: Tokens.lineStrong
        }
    }

    HoverHandler { id: cardHover }
}
