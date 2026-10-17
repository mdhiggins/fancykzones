import QtQuick
import QtQuick.Layouts

import "../components" as Components

Item {
    id: zones

    property var config
    property var layoutZones: []
    property var highlightedZone: []
    property bool spanning: false
    property var spanAnchor: []
    // proportions of the area the zones cover
    property real aspectRatio: 16 / 9
    readonly property size mapSize: getMapSize(140, 80, aspectRatio)
    // geometry of the area the zones are drawn in, zone geometries are absolute
    property var area: ({})

    property alias repeater: repeater

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

    Repeater {
        id: repeater

        model: layoutZones

        // zone
        Item {
            id: zone

            property int zoneIndex: index
            property var renderZones: config.zoneOverlayIndicatorDisplay == 1 ? [modelData] : layoutZones
            property int activeIndex: config.zoneOverlayIndicatorDisplay == 1 ? 0 : index

            property bool active: highlightedZone.includes(zoneIndex)

            x: modelData.rect.x - (area.x || 0)
            y: modelData.rect.y - (area.y || 0)
            implicitWidth: modelData.rect.width
            implicitHeight: modelData.rect.height

            // zone indicator
            Rectangle {
                id: zoneIndicator

                // grows when highlighted by resizing instead of scaling, a scaled card lands between pixels and looks blurry
                property real zoom: active ? 1.1 : 1

                width: Math.round((zones.mapSize.width + 20) * zoom / 2) * 2
                height: Math.round((zones.mapSize.height + 20) * zoom / 2) * 2
                color: colorHelper.backgroundColor
                radius: 10
                // spanning is shown by the badge, the border marks an included zone
                border.color: active ? colorHelper.accentColor : colorHelper.getBorderColor(color)
                border.width: active ? 2 : 1
                opacity: !showZoneOverlay ? 0 : (zoneSelector.expanded) ? 0 : (active ? 0.6 : 1)
                visible: config.enableZoneOverlay
                // centered on whole pixels
                x: Math.round((parent.width - width) / 2)
                y: Math.round((parent.height - height) / 2)

                Behavior on zoom {
                    NumberAnimation {
                        duration: zoneSelector.expanded ? 0 : 150
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                Components.Indicator {
                    indicatorZones: renderZones
                    activeZone: [activeIndex]
                    highlightedZone: zones.highlightedZone
                    // spanned or adjacent zones merge into one block
                    spanZones: config.zoneOverlayIndicatorDisplay != 1 && active && (zones.spanning || zones.highlightedZone.length > 1) ? zones.highlightedZone : []
                    // only spanning marks the zone it started from, adjacent zones have no start
                    anchorZones: zones.spanning ? zones.spanAnchor : []
                    anchors.centerIn: parent
                    width: parent.width - 20
                    height: parent.height - 20
                    hovering: (active)
                }

                Components.SpanBadge {
                    shown: zones.spanning
                    anchors.horizontalCenter: parent.right
                    anchors.verticalCenter: parent.top
                }
            }

            // zone border
            Rectangle {
                id: zoneBorder
                anchors.fill: parent
                color: "transparent"
                border.color: (active) ? colorHelper.accentColor : "transparent"
                border.width: 3
                radius: 8
            }

            // zone background
            Rectangle {
                id: zoneBackground
                opacity: (highlightedZone.includes(zoneIndex)) ? 0.1 : 0
                anchors.fill: parent
                color: colorHelper.accentColor
                radius: 8
            }

            // indicator shadow
            Components.Shadow {
                target: zoneIndicator
                visible: zoneIndicator.visible
            }

            Components.ColorHelper {
                id: colorHelper
            }
        }
    }
}
