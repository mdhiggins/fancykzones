import QtQuick
import QtQuick.Layouts

import "../components" as Components

Item {
    id: selector

    property var config
    property var layoutZones: []
    property var highlightedZone: []
    property bool spanning: false
    property var spanAnchor: []

    property bool expanded: false
    property bool near: false
    property bool animating: false

    property alias repeater: indicator.repeater

    visible: false
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    anchors.topMargin: expanded ? 0 : (near ? -height + 30 : -height)

    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: 150
            onRunningChanged: {
                if (!running)
                    selector.visible = true;
                selector.animating = running;
            }
        }
    }

    width: background.width + 30
    height: background.height + 40

    Rectangle {
        id: background

        width: row.implicitWidth + row.spacing * 2
        height: row.implicitHeight + row.spacing * 2
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 15
        color: colorHelper.backgroundColor
        radius: 10
        border.color: selector.spanning ? colorHelper.accentColor : colorHelper.getBorderColor(color)
        border.width: selector.spanning ? 2 : 1

        RowLayout {
            id: row

            spacing: 15
            anchors.fill: parent
            anchors.margins: spacing

            Components.Indicator {
                id: indicator
                indicatorZones: selector.layoutZones
                activeZone: selector.highlightedZone
                highlightedZone: selector.highlightedZone
                spanZones: selector.spanning ? selector.highlightedZone : []
                anchorZones: selector.spanAnchor
                width: 160 - 30
                height: 100 - 30
                Layout.preferredWidth: width
                Layout.preferredHeight: height
                hovering: true
            }
        }

        Components.SpanBadge {
            shown: selector.spanning
            anchors.horizontalCenter: parent.right
            anchors.verticalCenter: parent.top
        }
    }

    Components.Shadow {
        target: background
        visible: true
    }

    Components.ColorHelper {
        id: colorHelper
    }
}
