pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import Ryoku.Ui.Singletons
import shell.services

Item {
    id: root

    required property var notification
    property real us: 1
    property int lifespanMs: 0
    property string position: "Right"
    property bool showImages: true

    readonly property real pad: Tokens.s4 * us
    readonly property var visibleActions: {
        const source = root.notification?.actions || [];
        const result = [];
        for (let i = 0; i < source.length; ++i) {
            const candidate = source[i];
            if (candidate && candidate.identifier !== "default"
                    && String(candidate.text || "").length > 0)
                result.push(candidate);
        }
        return result;
    }
    readonly property var defaultAction: {
        const source = root.notification?.actions || [];
        for (let i = 0; i < source.length; ++i) {
            if (source[i] && source[i].identifier === "default")
                return source[i];
        }
        return null;
    }
    readonly property string pictureSource: showImages
        ? String(root.notification?.image || "") : ""

    implicitHeight: content.implicitHeight + pad * 2

    function invokeAndDismiss(action): void {
        if (action && typeof action.invoke === "function")
            action.invoke();
        Notifs.dismiss(root.notification);
    }

    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius * root.us
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.line
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Tokens.s3 * root.us

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.s2 * root.us

            Image {
                readonly property string rawIcon: String(root.notification?.appIcon || "")
                Layout.preferredWidth: 24 * root.us
                Layout.preferredHeight: 24 * root.us
                visible: rawIcon !== ""
                source: rawIcon === "" ? ""
                    : rawIcon.indexOf("/") >= 0 || rawIcon.indexOf(":") >= 0
                        ? rawIcon : Icons.path(rawIcon, true)
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            Text {
                Layout.fillWidth: true
                text: root.notification?.appName || I18n.tr("Notification")
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.us
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 28 * root.us
                Layout.preferredHeight: 28 * root.us
                radius: Tokens.radius * root.us
                color: closeHover.hovered ? Tokens.tint10 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody * root.us
                }
                HoverHandler { id: closeHover }
                TapHandler { onTapped: Notifs.dismiss(root.notification) }
            }
        }

        Image {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 120 * root.us : 0
            visible: root.pictureSource !== ""
            source: root.pictureSource
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            clip: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.s1 * root.us

            Text {
                Layout.fillWidth: true
                text: root.notification?.summary || ""
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody * root.us
                font.weight: Font.Bold
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            Text {
                Layout.fillWidth: true
                visible: String(root.notification?.body || "").length > 0
                text: root.notification?.body || ""
                textFormat: Text.StyledText
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.us
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }

            TapHandler {
                enabled: root.defaultAction !== null
                onTapped: root.invokeAndDismiss(root.defaultAction)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Tokens.s2 * root.us
            visible: root.visibleActions.length > 0

            Repeater {
                model: root.visibleActions

                delegate: Rectangle {
                    id: actionButton
                    required property var modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 36 * root.us
                    radius: Tokens.radius * root.us
                    color: actionHover.hovered || actionTap.pressed
                        ? Tokens.bone : Tokens.paper
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - Tokens.s4 * root.us
                        horizontalAlignment: Text.AlignHCenter
                        text: actionButton.modelData.text
                        color: actionHover.hovered || actionTap.pressed
                            ? Tokens.inkOnBone : Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.us
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    HoverHandler { id: actionHover }
                    TapHandler {
                        id: actionTap
                        onTapped: root.invokeAndDismiss(actionButton.modelData)
                    }
                }
            }
        }
    }
}
