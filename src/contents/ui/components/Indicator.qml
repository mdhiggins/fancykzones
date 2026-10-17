import QtQuick

import "../components" as Components

Rectangle {
    id: indicator
    property var activeZone: []
    property var highlightedZone: []
    property bool hovering: false
    property var indicatorZones: []
    // zones to draw as one merged block while spanning, and the zones the span started from
    property var spanZones: []
    property var anchorZones: []
    property alias repeater: indicators
    width: parent.width
    height: parent.height
    color: "transparent"
    opacity: 1

    Repeater {
        id: indicators
        model: indicatorZones

        Item {
            id: zone
            x: ((modelData.x / 100) * (indicator.width))
            y: ((modelData.y / 100) * (indicator.height))
            width: ((modelData.width / 100) * (indicator.width))
            height: ((modelData.height / 100) * (indicator.height))
            z: activeZone.includes(index) ? 1 : 0

            Rectangle {
                property int padding: 2
                anchors.fill: parent
                anchors.margins: padding
                color: {
                    // covered by the merged span block
                    if (indicator.spanZones.includes(index)) {
                        return "transparent";
                    } else if (activeZone.includes(index)) {
                        return colorHelper.accentColor;
                    } else if (indicator.highlightedZone.includes(index) && indicator.highlightedZone.includes(activeIndex)) {
                        return Qt.rgba(colorHelper.accentColor.r, colorHelper.accentColor.g, colorHelper.accentColor.b, 0.2);
                    } else {
                        return colorHelper.buttonColor;
                    }
                }
                border.color: colorHelper.getBorderColor(color)
                border.width: indicator.spanZones.includes(index) ? 0 : 1
                radius: 5

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }

    function getSpanRect(spanZones, zones, width, height) {
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        spanZones.forEach(zoneIndex => {
            const zone = zones[zoneIndex];
            if (!zone)
                return;
            minX = Math.min(minX, zone.x);
            minY = Math.min(minY, zone.y);
            maxX = Math.max(maxX, zone.x + zone.width);
            maxY = Math.max(maxY, zone.y + zone.height);
        });
        if (minX === Infinity)
            return null;
        return {
            x: minX / 100 * width,
            y: minY / 100 * height,
            width: (maxX - minX) / 100 * width,
            height: (maxY - minY) / 100 * height
        };
    }

    // spanned zones melt into a single block
    Rectangle {
        id: spanBlock

        property var spanRect: indicator.getSpanRect(indicator.spanZones, indicator.indicatorZones, indicator.width, indicator.height)
        property int padding: 2

        z: 2
        x: (spanRect ? spanRect.x : 0) + padding
        y: (spanRect ? spanRect.y : 0) + padding
        width: Math.max(0, (spanRect ? spanRect.width : 0) - padding * 2)
        height: Math.max(0, (spanRect ? spanRect.height : 0) - padding * 2)
        opacity: spanRect ? 1 : 0
        visible: opacity > 0
        color: colorHelper.accentColor
        border.color: colorHelper.getBorderColor(color)
        border.width: 1
        radius: 5

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 150
            }
        }
    }

    // dot on the zones the span started from
    Repeater {
        model: indicator.spanZones.length > 0 ? indicator.anchorZones.filter(zoneIndex => indicator.indicatorZones[zoneIndex]) : []

        Rectangle {
            readonly property var zone: indicator.indicatorZones[modelData]

            z: 3
            width: 6
            height: 6
            radius: 3
            x: (zone.x + zone.width / 2) / 100 * indicator.width - width / 2
            y: (zone.y + zone.height / 2) / 100 * indicator.height - height / 2
            color: colorHelper.backgroundColor
        }
    }

    Components.ColorHelper {
        id: colorHelper
    }
}
