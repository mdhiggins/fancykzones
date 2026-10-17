import QtQuick
import QtQuick.Shapes

import "../components" as Components

Item {
    id: dwellIndicator

    property int duration: 600
    property real progress: 0
    // a reversed dwell drains the ring instead of filling it
    property bool reversed: false
    // fraction of the dwell that has passed, in both directions
    readonly property real elapsed: reversed ? 1 - progress : progress

    signal dwellFinished

    function restart(reverse) {
        progressAnimation.stop();
        reversed = !!reverse;
        progressAnimation.restart();
    }

    function stop() {
        progressAnimation.stop();
        progress = 0;
    }

    width: 56
    height: 56

    NumberAnimation {
        id: progressAnimation
        target: dwellIndicator
        property: "progress"
        from: dwellIndicator.reversed ? 1 : 0
        to: dwellIndicator.reversed ? 0 : 1
        duration: dwellIndicator.duration
        onFinished: {
            if (dwellIndicator.elapsed < 1)
                return;
            burstAnimation.restart();
            dwellIndicator.dwellFinished();
        }
    }

    // progress ring
    Item {
        id: ring
        anchors.fill: parent
        // short pauses should not flash the indicator
        opacity: progressAnimation.running && dwellIndicator.elapsed > 0.2 ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 100
            }
        }

        Components.Shadow {
            target: background
        }

        Rectangle {
            id: background
            anchors.fill: parent
            radius: width / 2
            color: colorHelper.backgroundColor
            border.color: colorHelper.getBorderColor(color)
            border.width: 1
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            // track
            ShapePath {
                strokeColor: colorHelper.buttonColor
                strokeWidth: 5
                fillColor: "transparent"
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.width / 2 - 10
                    radiusY: ring.height / 2 - 10
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            // progress
            ShapePath {
                strokeColor: colorHelper.accentColor
                strokeWidth: 5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: ring.width / 2
                    centerY: ring.height / 2
                    radiusX: ring.width / 2 - 10
                    radiusY: ring.height / 2 - 10
                    startAngle: -90
                    sweepAngle: 360 * dwellIndicator.progress
                }
            }
        }
    }

    // short burst when spanning starts, or implodes when it stops
    Rectangle {
        id: burst
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: colorHelper.accentColor
        border.width: 3
        opacity: 0

        ParallelAnimation {
            id: burstAnimation
            NumberAnimation {
                target: burst
                property: "scale"
                from: dwellIndicator.reversed ? 1.6 : 0.6
                to: dwellIndicator.reversed ? 0.6 : 1.6
                duration: 250
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: burst
                property: "opacity"
                from: 1
                to: 0
                duration: 250
                easing.type: Easing.OutQuad
            }
        }
    }

    Components.ColorHelper {
        id: colorHelper
    }
}
