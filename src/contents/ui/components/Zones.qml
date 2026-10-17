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
    // geometry of the area the zones are drawn in, zone geometries are absolute
    property var area: ({})

    property alias repeater: repeater

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

                width: 160
                height: 100
                color: colorHelper.backgroundColor
                radius: 10
                border.color: zones.spanning ? colorHelper.accentColor : colorHelper.getBorderColor(color)
                border.width: zones.spanning ? 2 : 1
                opacity: !showZoneOverlay ? 0 : (zoneSelector.expanded) ? 0 : (active ? 0.6 : 1)
                scale: active ? 1.1 : 1
                visible: config.enableZoneOverlay
                anchors.centerIn: parent

                Behavior on scale {
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
                    spanZones: zones.spanning && config.zoneOverlayIndicatorDisplay != 1 && active ? zones.highlightedZone : []
                    anchorZones: zones.spanAnchor
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
