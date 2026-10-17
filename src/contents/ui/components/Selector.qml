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
    // proportions of the area the zones cover
    property real aspectRatio: 16 / 9
    readonly property size mapSize: getMapSize(130, 70, aspectRatio)

    property bool expanded: false
    property bool near: false
    property bool animating: false

    property alias repeater: indicator.repeater

    // size of a zone minimap with the proportions of the screen, about as large as a 16:9 one of the given size
    function getMapSize(baseWidth, baseHeight, aspectRatio) {
        const area = baseWidth * baseHeight;
        let width = Math.sqrt(area * aspectRatio);
        let height = width / aspectRatio;
        // keep very wide or very tall screens within reason
        const scale = Math.min(1, baseWidth * 2 / width, baseHeight * 2 / height);
        // even sizes keep centered items on whole pixels
        return Qt.size(Math.round(width * scale / 2) * 2, Math.round(height * scale / 2) * 2);
    }

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
        border.color: colorHelper.getBorderColor(color)
        border.width: 1

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
                // spanned or adjacent zones merge into one block
                spanZones: selector.spanning || selector.highlightedZone.length > 1 ? selector.highlightedZone : []
                // only spanning marks the zone it started from, adjacent zones have no start
                anchorZones: selector.spanning ? selector.spanAnchor : []
                width: selector.mapSize.width
                height: selector.mapSize.height
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
