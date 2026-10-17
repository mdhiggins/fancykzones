import QtQuick
import org.kde.kwin

Item {
    signal moveActiveWindowToNextZone
    signal moveActiveWindowToPreviousZone
    signal toggleZoneOverlay
    signal toggleZoneSpanning
    signal switchToNextWindowInCurrentZone
    signal switchToPreviousWindowInCurrentZone
    signal moveActiveWindowToZone(int zone)
    signal moveActiveWindowUp
    signal moveActiveWindowDown
    signal moveActiveWindowLeft
    signal moveActiveWindowRight
    signal snapActiveWindow
    signal snapAllWindows
    signal restoreActiveWindow

    ShortcutHandler {
        name: "FancyKZones: Move active window to next zone"
        text: "FancyKZones: Move active window to next zone"
        sequence: "Ctrl+Alt+Right"
        onActivated: {
            moveActiveWindowToNextZone();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Move active window to previous zone"
        text: "FancyKZones: Move active window to previous zone"
        sequence: "Ctrl+Alt+Left"
        onActivated: {
            moveActiveWindowToPreviousZone();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Toggle zone overlay"
        text: "FancyKZones: Toggle zone overlay"
        sequence: "Ctrl+Alt+C"
        onActivated: {
            toggleZoneOverlay();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Toggle zone spanning"
        text: "FancyKZones: Toggle zone spanning"
        sequence: "Ctrl+Alt+V"
        onActivated: {
            toggleZoneSpanning();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Switch to next window in current zone"
        text: "FancyKZones: Switch to next window in current zone"
        sequence: "Ctrl+Alt+Up"
        onActivated: {
            switchToNextWindowInCurrentZone();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Switch to previous window in current zone"
        text: "FancyKZones: Switch to previous window in current zone"
        sequence: "Ctrl+Alt+Down"
        onActivated: {
            switchToPreviousWindowInCurrentZone();
        }
    }

    Repeater {
        model: [1, 2, 3, 4, 5, 6, 7, 8, 9]

        delegate: Item {
            ShortcutHandler {
                name: "FancyKZones: Move active window to zone " + modelData
                text: "FancyKZones: Move active window to zone " + modelData
                sequence: "Ctrl+Alt+Num+" + modelData
                onActivated: {
                    moveActiveWindowToZone(modelData - 1);
                }
            }
        }
    }

    Repeater {
        model: [1, 2, 3, 4, 5, 6, 7, 8, 9]

        delegate: Item {}
    }

    ShortcutHandler {
        name: "FancyKZones: Move active window up"
        text: "FancyKZones: Move active window up"
        sequence: "Meta+Up"
        onActivated: {
            moveActiveWindowUp();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Move active window down"
        text: "FancyKZones: Move active window down"
        sequence: "Meta+Down"
        onActivated: {
            moveActiveWindowDown();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Move active window left"
        text: "FancyKZones: Move active window left"
        sequence: "Meta+Left"
        onActivated: {
            moveActiveWindowLeft();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Move active window right"
        text: "FancyKZones: Move active window right"
        sequence: "Meta+Right"
        onActivated: {
            moveActiveWindowRight();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Snap active window"
        text: "FancyKZones: Snap active window"
        sequence: "Meta+Shift+Space"
        onActivated: {
            snapActiveWindow();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Snap all windows"
        text: "FancyKZones: Snap all windows"
        sequence: "Meta+Space"
        onActivated: {
            snapAllWindows();
        }
    }

    ShortcutHandler {
        name: "FancyKZones: Restore active window"
        text: "FancyKZones: Restore active window"
        sequence: "Meta+Backspace"
        onActivated: {
            restoreActiveWindow();
        }
    }
}
