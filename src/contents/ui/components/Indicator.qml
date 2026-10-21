import QtQuick

import "../components" as Components

Rectangle {
    id: indicator
    property var activeZone: []
    property var highlightedZone: []
    property bool hovering: false
    property var indicatorZones: []
    // zones to draw as one merged block, and the zones a span started from
    property var spanZones: []
    property var anchorZones: []
    // area of the merged block in percentages, zones inside it are hidden
    readonly property var spanBounds: getSpanBounds(spanZones, indicatorZones)
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
            // edges snapped to whole pixels, fractional edges are drawn blurry
            x: Math.round(modelData.x / 100 * indicator.width)
            y: Math.round(modelData.y / 100 * indicator.height)
            width: Math.round((modelData.x + modelData.width) / 100 * indicator.width) - x
            height: Math.round((modelData.y + modelData.height) / 100 * indicator.height) - y
            z: activeZone.includes(index) ? 1 : 0

            Rectangle {
                property int padding: 2
                anchors.fill: parent
                anchors.margins: padding
                color: {
                    // covered by the merged span block
                    if (indicator.isCovered(modelData)) {
                        return "transparent";
                    } else if (activeZone.includes(index)) {
                        // full accent only while the zone is included, otherwise a muted hint of which zone this is
                        return indicator.hovering ? colorHelper.accentColor : colorHelper.tintWithAlpha(colorHelper.buttonColor, colorHelper.accentColor, 0.35);
                    } else if (indicator.highlightedZone.includes(index) && indicator.highlightedZone.includes(activeIndex)) {
                        return Qt.rgba(colorHelper.accentColor.r, colorHelper.accentColor.g, colorHelper.accentColor.b, 0.2);
                    } else {
                        return colorHelper.buttonColor;
                    }
                }
                border.color: colorHelper.getBorderColor(color)
                border.width: indicator.isCovered(modelData) ? 0 : 1
                radius: 5

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                    }
                }
            }
        }
    }

    function getSpanBounds(spanZones, zones) {
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
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        };
    }

    function isCovered(zone) {
        const bounds = indicator.spanBounds;
        if (!bounds)
            return false;
        const epsilon = 0.01;
        return zone.x >= bounds.x - epsilon && zone.y >= bounds.y - epsilon && zone.x + zone.width <= bounds.x + bounds.width + epsilon && zone.y + zone.height <= bounds.y + bounds.height + epsilon;
    }

    // spanned zones melt into a single block, it grows out of and shrinks back into the highlighted zone
    Rectangle {
        id: spanBlock

        property int padding: 2
        // position and size in percentages, animated on their own so the block follows the indicator when it is resized
        property real boundsX: 0
        property real boundsY: 0
        property real boundsWidth: 0
        property real boundsHeight: 0
        // same whole pixel edges as the zones underneath
        readonly property int edgeLeft: Math.round(boundsX / 100 * indicator.width)
        readonly property int edgeTop: Math.round(boundsY / 100 * indicator.height)
        readonly property int edgeRight: Math.round((boundsX + boundsWidth) / 100 * indicator.width)
        readonly property int edgeBottom: Math.round((boundsY + boundsHeight) / 100 * indicator.height)

        function place(bounds, animated) {
            if (!bounds)
                return;
            if (animated) {
                xAnimation.to = bounds.x;
                yAnimation.to = bounds.y;
                widthAnimation.to = bounds.width;
                heightAnimation.to = bounds.height;
                geometryAnimation.restart();
            } else {
                geometryAnimation.stop();
                boundsX = bounds.x;
                boundsY = bounds.y;
                boundsWidth = bounds.width;
                boundsHeight = bounds.height;
            }
        }

        function update() {
            const home = indicator.getSpanBounds(indicator.activeZone, indicator.indicatorZones);
            if (indicator.spanBounds) {
                hideTimer.stop();
                if (!visible) {
                    // start from the zone it was resting on
                    if (boundsWidth === 0 && home)
                        place(home, false);
                    visible = true;
                }
                place(indicator.spanBounds, true);
            } else if (visible) {
                if (home) {
                    place(home, true);
                    hideTimer.restart();
                } else {
                    visible = false;
                }
            } else if (indicator.activeZone.length === 1) {
                // rest on the highlighted zone, ready to grow out of it
                place(home, false);
            }
        }

        z: 2
        visible: false
        x: edgeLeft + padding
        y: edgeTop + padding
        width: Math.max(0, edgeRight - edgeLeft - padding * 2)
        height: Math.max(0, edgeBottom - edgeTop - padding * 2)
        color: colorHelper.accentColor
        border.color: colorHelper.getBorderColor(color)
        border.width: 1
        radius: 5

        ParallelAnimation {
            id: geometryAnimation

            NumberAnimation {
                id: xAnimation
                target: spanBlock
                property: "boundsX"
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: yAnimation
                target: spanBlock
                property: "boundsY"
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: widthAnimation
                target: spanBlock
                property: "boundsWidth"
                duration: 150
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: heightAnimation
                target: spanBlock
                property: "boundsHeight"
                duration: 150
                easing.type: Easing.OutCubic
            }
        }

        // hide once it has shrunk back into the zone
        Timer {
            id: hideTimer
            interval: 150
            onTriggered: spanBlock.visible = false
        }
    }

    onSpanBoundsChanged: spanBlock.update()
    onActiveZoneChanged: spanBlock.update()
    Component.onCompleted: spanBlock.update()

    // dot on the zones the span started from
    Repeater {
        model: indicator.spanZones.length > 0 ? indicator.anchorZones.filter(zoneIndex => indicator.indicatorZones[zoneIndex]) : []

        Rectangle {
            readonly property var zone: indicator.indicatorZones[modelData]

            z: 3
            width: 6
            height: 6
            radius: 3
            x: Math.round((zone.x + zone.width / 2) / 100 * indicator.width - width / 2)
            y: Math.round((zone.y + zone.height / 2) / 100 * indicator.height - height / 2)
            color: colorHelper.backgroundColor
            // only shown once the block has grown over it, so the block expands to the whole span first like adjacent zones do
            opacity: spanBlock.visible && x >= spanBlock.x && x + width <= spanBlock.x + spanBlock.width && y >= spanBlock.y && y + height <= spanBlock.y + spanBlock.height ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 100
                }
            }
        }
    }

    Components.ColorHelper {
        id: colorHelper
    }
}
