import QtQuick
import org.kde.kirigami as Kirigami

import "../components" as Components

// chain link badge that pops up on the indicators while spanning
Rectangle {
    id: badge

    property bool shown: false

    width: 24
    height: 24
    radius: width / 2
    color: colorHelper.accentColor
    border.color: colorHelper.getBorderColor(color)
    border.width: 1
    scale: shown ? 1 : 0
    visible: scale > 0
    z: 10

    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutBack
        }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "link"
        isMask: true
        color: colorHelper.backgroundColor
    }

    Components.ColorHelper {
        id: colorHelper
    }
}
