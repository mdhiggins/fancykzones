import QtQuick
import QtQuick.Layouts
import org.kde.kwin
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.core as PlasmaCore

import "components" as Components

PlasmaCore.Dialog {

    // api documentation
    // https://api.kde.org/frameworks/plasma-framework/html/classPlasmaQuick_1_1Dialog.html
    // https://api.kde.org/frameworks/plasma-framework/html/classPlasma_1_1Types.html
    // https://develop.kde.org/docs/getting-started/kirigami/style-colors/

    id: mainDialog

    // properties
    property bool shown: false
    // the overlay is shown once invisibly after login, see warmUpTimer
    property bool warmingUp: false
    property bool moving: false
    property bool moved: false
    property bool resizing: false
    property var clientArea: ({})
    property var displaySize: ({})
    property var currentLayout: ({
            key: "",
            zones: []
        })
    property var highlightedZone: []
    property var activeScreen: null
    property var config: ({})
    property bool showZoneOverlay: config.zoneOverlayShowWhen == 0
    property var errors: []
    property bool enteredEdge: false
    property bool enableSpanning: false
    // zones the span starts from, the span covers these and the zone under the cursor
    property var spanAnchor: []
    property var dwellPoint: null
    // tile geometries from before a resize, so the layout can be put back afterwards
    property var layoutSnapshot: []
    // after a dwell the cursor has to leave the indicator before the next one can start
    property bool dwellNeedsLeave: false

    title: "FancyKZones Overlay"
    location: PlasmaCore.Types.Desktop
    type: PlasmaCore.Dialog.OnScreenDisplay
    backgroundHints: PlasmaCore.Types.NoBackground
    flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.Popup
    hideOnWindowDeactivate: true
    visible: false
    outputOnly: true
    opacity: 1
    width: displaySize.width
    height: displaySize.height

    function loadConfig() {
        // load values from configuration
        config = {
            // enable zone selector
            enableZoneSelector: KWin.readConfig("enableZoneSelector", true),
            // distance from the top of the screen to trigger the zone selector
            zoneSelectorTriggerDistance: KWin.readConfig("zoneSelectorTriggerDistance", 1),
            // enable zone overlay
            enableZoneOverlay: KWin.readConfig("enableZoneOverlay", true),
            // show zone overlay when
            zoneOverlayShowWhen: KWin.readConfig("zoneOverlayShowWhen", 0),
            // highlight target zone
            zoneOverlayHighlightTarget: KWin.readConfig("zoneOverlayHighlightTarget", 0),
            // zone overlay indicator display
            zoneOverlayIndicatorDisplay: KWin.readConfig("zoneOverlayIndicatorDisplay", 0),
            // enable edge snapping
            enableEdgeMode: KWin.readConfig("enableEdgeMode", 0),
            // distance from the edge of the screen to trigger the edge snapping
            edgeSnappingTriggerDistance: KWin.readConfig("edgeSnappingTriggerDistance", 1),
            // bumping the edge to show the overlay also starts spanning
            bumpStartsSpanning: KWin.readConfig("bumpStartsSpanning", false),
            // remember window geometries before snapping to a zone, and restore them when the window is removed from their zone
            rememberWindowGeometries: KWin.readConfig("rememberWindowGeometries", true),
            // show osd messages
            showOsdMessages: KWin.readConfig("showOsdMessages", true),
            // fade windows while moving
            fadeWindowsWhileMoving: KWin.readConfig("fadeWindowsWhileMoving", false),
            // zone spanning distance in pixels (if 0 span logic is skipped)
            zoneSpanningDistance: KWin.readConfig("zoneSpanningDistance", 0),
            // hold the cursor still over a zone to start spanning from it
            enableDwellSpanning: KWin.readConfig("enableDwellSpanning", true),
            // how long the cursor needs to be held still in milliseconds
            dwellSpanningDelay: KWin.readConfig("dwellSpanningDelay", 600),
            // auto snap all windows
            autoSnapAllNew: KWin.readConfig("autoSnapAllNew", false),
            // filter mode
            filterMode: KWin.readConfig("filterMode", 0),
            // filter list
            filterList: KWin.readConfig("filterList", ""),
            // polling rate in milliseconds
            pollingRate: KWin.readConfig("pollingRate", 100),
            // enable debug logging
            enableDebugLogging: KWin.readConfig("enableDebugLogging", false),
            // enable debug overlay
            enableDebugOverlay: KWin.readConfig("enableDebugOverlay", false)
        };

        if (config.zoneSpanningDistance > 0) {
            config.zoneOverlayHighlightTarget = 1;
        }

        log("Config loaded: " + JSON.stringify(config));
    }

    function log(message) {
        if (!config.enableDebugLogging)
            return;
        console.log("FancyKZones: " + message);
    }

    function show() {
        // show OSD
        mainDialog.shown = true;
        mainDialog.visible = true;
        mainDialog.setWidth(Workspace.virtualScreenSize.width);
        mainDialog.setHeight(Workspace.virtualScreenSize.height);
        refreshClientArea();
    }

    function hide() {
        // hide OSD
        mainDialog.shown = false;
        mainDialog.visible = false;
        zoneSelector.expanded = false;
        zoneSelector.near = false;
        enableSpanning = false;
        highlightedZone = [];
        showZoneOverlay = config.zoneOverlayShowWhen == 0;
        spanAnchor = [];
        dwellNeedsLeave = false;
        stopDwell();
    }

    function refreshClientArea() {
        activeScreen = Workspace.activeScreen;
        clientArea = Workspace.clientArea(KWin.FullScreenArea, activeScreen, getDesktop(activeScreen));
        displaySize = Workspace.virtualScreenSize;
        // only replace the layout when it changed, so the overlay is not rebuilt on every poll
        const layout = getLayout(activeScreen);
        if (!isSameLayout(layout, currentLayout)) {
            log("Layout changed to " + layout.key + " with " + layout.zones.length + " zones");
            currentLayout = layout;
        }
    }

    // layouts are the kwin tiling layouts (edited with meta+t), one per screen and virtual desktop

    function getDesktop(output) {
        // since plasma 6.7 every screen can show a different virtual desktop
        if (Workspace.currentDesktopForScreen)
            return Workspace.currentDesktopForScreen(output);
        return Workspace.currentDesktop;
    }

    function getRootTile(output, desktop) {
        if (Workspace.rootTile)
            return Workspace.rootTile(output, desktop);
        // plasma < 6.5 has a single tiling layout per screen
        const tileManager = Workspace.tilingForScreen(output.name);
        return tileManager ? tileManager.rootTile : null;
    }

    function getLeafTiles(tile) {
        if (tile.tiles.length === 0)
            return [tile];
        let leaves = [];
        for (let i = 0; i < tile.tiles.length; i++) {
            leaves = leaves.concat(getLeafTiles(tile.tiles[i]));
        }
        return leaves;
    }

    function getLayout(output) {
        if (!output)
            return {
                key: "",
                zones: []
            };
        const desktop = getDesktop(output);
        const rootTile = getRootTile(output, desktop);
        const screenArea = Workspace.clientArea(KWin.FullScreenArea, output, desktop);
        // tiles cover the screen minus panels, the indicators use its proportions
        const tileArea = Workspace.clientArea(KWin.MaximizeArea, output, desktop);
        const zones = [];
        if (rootTile) {
            getLeafTiles(rootTile).forEach(tile => {
                // the tiles editor can leave collapsed tiles behind
                if (tile.relativeGeometry.width <= 0 || tile.relativeGeometry.height <= 0)
                    return;
                zones.push(createZone(tile, screenArea));
            });
        }
        return {
            key: output.name + "|" + desktop.id,
            zones: zones,
            aspectRatio: tileArea.height > 0 ? tileArea.width / tileArea.height : 16 / 9
        };
    }

    function createZone(tile, screenArea) {
        const rel = tile.relativeGeometry;
        const abs = tile.absoluteGeometry;
        const padding = tile.padding;
        // same as Tile::windowGeometry() in kwin: half padding between tiles, full padding against the screen edges
        const left = Math.max(abs.x, screenArea.x) + (rel.x > 0 ? padding / 2 : padding);
        const top = Math.max(abs.y, screenArea.y) + (rel.y > 0 ? padding / 2 : padding);
        const right = Math.min(abs.x + abs.width, screenArea.x + screenArea.width) - (rel.x + rel.width < 1 ? padding / 2 : padding);
        const bottom = Math.min(abs.y + abs.height, screenArea.y + screenArea.height) - (rel.y + rel.height < 1 ? padding / 2 : padding);
        return {
            tile: tile,
            // position and size in percentage of the screen, used by the indicators and the neighbour lookup
            x: rel.x * 100,
            y: rel.y * 100,
            width: rel.width * 100,
            height: rel.height * 100,
            padding: padding,
            // tile area without padding
            area: {
                x: abs.x,
                y: abs.y,
                width: abs.width,
                height: abs.height
            },
            // geometry a window gets in this zone
            rect: {
                x: left,
                y: top,
                width: right - left,
                height: bottom - top
            }
        };
    }

    function isSameRect(a, b) {
        return Math.abs(a.x - b.x) <= 1 && Math.abs(a.y - b.y) <= 1 && Math.abs(a.width - b.width) <= 1 && Math.abs(a.height - b.height) <= 1;
    }

    function isSameLayout(a, b) {
        if (a.key !== b.key || a.zones.length !== b.zones.length || a.aspectRatio !== b.aspectRatio)
            return false;
        return a.zones.every((zone, i) => zone.tile === b.zones[i].tile && isSameRect(zone.rect, b.zones[i].rect));
    }

    function isCustomTile(tile) {
        // quick tiles (half/quarter screen) have no layout direction, only tiles from the tiling layout do
        return !!tile && tile.layoutDirection !== undefined;
    }

    function manageClient(tile, client) {
        if (tile.manage)
            return tile.manage(client);
        // plasma < 6.5 tiles windows by assigning the tile
        client.tile = tile;
        return client.tile === tile;
    }

    function unmanageClient(client) {
        if (client.tile.unmanage)
            client.tile.unmanage(client);
        else
            client.tile = null;
    }

    function getClientZoneTiles(client) {
        // windows in a single zone are managed by kwin, spanned windows are tracked by us
        if (isCustomTile(client.tile))
            return [client.tile];
        return client.zoneTiles || [];
    }

    function getClientZone(client, layout) {
        const zone = getClientZoneTiles(client).map(tile => layout.zones.findIndex(candidate => candidate.tile === tile));
        // tiles from another screen, desktop or a removed tile
        if (zone.includes(-1))
            return [];
        return zone.sort((a, b) => a - b);
    }

    function getZoneGeometry(zones) {
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        zones.forEach(zone => {
            minX = Math.min(minX, zone.rect.x);
            minY = Math.min(minY, zone.rect.y);
            maxX = Math.max(maxX, zone.rect.x + zone.rect.width);
            maxY = Math.max(maxY, zone.rect.y + zone.rect.height);
        });
        return Qt.rect(Math.round(minX), Math.round(minY), Math.round(maxX - minX), Math.round(maxY - minY));
    }

    function setZoneTiles(client, tiles) {
        // stop following the previous tiles
        if (client.followZoneTiles) {
            (client.zoneTiles || []).forEach(tile => {
                try {
                    tile.windowGeometryChanged.disconnect(client.followZoneTiles);
                } catch (e) {
                    // tile was already removed
                }
            });
            client.followZoneTiles = null;
        }
        client.zoneTiles = tiles;
        if (tiles.length === 0)
            return;

        // kwin only moves the windows it manages, so follow the tiles when the layout is edited
        client.followZoneTiles = () => {
            if (client.move || client.resize || isCustomTile(client.tile))
                return;
            if (client.zoneTiles.some(tile => !tile.relativeGeometry))
                return;
            const screenArea = Workspace.clientArea(KWin.FullScreenArea, client.output, getDesktop(client.output));
            const newGeometry = getZoneGeometry(client.zoneTiles.map(tile => createZone(tile, screenArea)));
            if (!isSameRect(newGeometry, client.frameGeometry)) {
                log("Following tiles for client " + client.resourceClass.toString() + " with geometry " + JSON.stringify(newGeometry));
                client.frameGeometry = newGeometry;
            }
        };
        tiles.forEach(tile => tile.windowGeometryChanged.connect(client.followZoneTiles));
    }

    function isPointInside(x, y, geometry) {
        return x >= geometry.x && x <= geometry.x + geometry.width && y >= geometry.y && y <= geometry.y + geometry.height;
    }

    function isHovering(item) {
        if (!item)
            return false;
        const itemGlobal = item.mapToGlobal(Qt.point(0, 0));
        return isPointInside(Workspace.cursorPos.x, Workspace.cursorPos.y, {
            x: itemGlobal.x,
            y: itemGlobal.y,
            width: item.width * item.scale,
            height: item.height * item.scale
        });
    }

    function checkFilter(client) {
        if (!client)
            return false;
        if (!client.normalWindow)
            return false;
        if (client.popupWindow)
            return false;
        if (client.skipTaskbar)
            return false;

        const filter = config.filterList.split(/\r?\n/);
        if (config.filterList.length > 0) {
            if (config.filterMode == 0) {
                // include
                return filter.includes(client.resourceClass.toString());
            }
            if (config.filterMode == 1) {
                // exclude
                return !filter.includes(client.resourceClass.toString());
            }
        }
        return true;
    }

    function matchZone(client) {
        // kwin already knows which tile the window is in
        if (isCustomTile(client.tile))
            return;

        const layout = getLayout(client.output);
        // loop through zones and compare with the geometries of the client
        const zone = layout.zones.find(zone => isSameRect(zone.rect, client.frameGeometry));
        setZoneTiles(client, zone ? [zone.tile] : []);
    }

    function getWindowsInZone(tile) {
        const windows = [];
        const activeWindow = Workspace.activeWindow;
        for (let i = 0; i < Workspace.stackingOrder.length; i++) {
            const client = Workspace.stackingOrder[i];
            if (!checkFilter(client) || !getClientZoneTiles(client).includes(tile))
                continue;
            if (client.output !== activeWindow.output)
                continue;
            if (!client.onAllDesktops && !client.desktops.includes(getDesktop(client.output)))
                continue;
            if (client.activities.length > 0 && !client.activities.includes(Workspace.currentActivity))
                continue;
            windows.push(client);
        }
        return windows;
    }

    function switchWindowInZone(tile, reverse) {
        const clientsInZone = getWindowsInZone(tile);
        if (reverse)
            clientsInZone.reverse();

        // cycle through clients in zone
        if (clientsInZone.length > 0) {
            const index = clientsInZone.indexOf(Workspace.activeWindow);
            if (index === -1) {
                Workspace.activeWindow = clientsInZone[0];
            } else {
                Workspace.activeWindow = clientsInZone[(index + 1) % clientsInZone.length];
            }
        }
    }

    function moveClientToZone(client, zone, layout) {
        // block abnormal windows from being moved (like plasmashell, docks, etc...)
        if (!checkFilter(client))
            return;

        refreshClientArea();
        if (!layout)
            layout = getLayout(client.output);

        const zones = zone.map(zoneIndex => layout.zones[zoneIndex]).filter(zone => zone !== undefined);

        log("Moving client " + client.resourceClass.toString() + " to zone " + JSON.stringify(zone));

        saveClientGeometry(client, zones);

        if (zones.length === 0) {
            setZoneTiles(client, []);
            return;
        }

        // a single zone is a kwin tile, let kwin manage the window so it follows the tile when the layout is edited
        if (zones.length === 1 && manageClient(zones[0].tile, client)) {
            log("Client " + client.resourceClass.toString() + " is managed by tile " + zone[0]);
            setZoneTiles(client, []);
            return;
        }

        // spanned zones are not a single tile, so the window is placed by us
        if (client.tile)
            unmanageClient(client);
        setZoneTiles(client, zones.map(zone => zone.tile));
        const newGeometry = getZoneGeometry(zones);
        log("Moving client " + client.resourceClass.toString() + " to zones " + JSON.stringify(zone) + " with geometry " + JSON.stringify(newGeometry));
        client.setMaximize(false, false);
        client.frameGeometry = newGeometry;
    }

    function restoreClientGeometry(client) {
        if (!checkFilter(client) || getClientZoneTiles(client).length === 0)
            return;

        log("Restoring geometry for client " + client.resourceClass.toString());
        // kwin restores the geometry from before tiling when the window leaves its tile
        if (isCustomTile(client.tile))
            unmanageClient(client);
        setZoneTiles(client, []);
        if (config.rememberWindowGeometries && client.oldGeometry) {
            const geometry = client.oldGeometry;
            client.frameGeometry = Qt.rect(geometry.x, geometry.y, geometry.width, geometry.height);
        }
    }

    function saveClientGeometry(client, zones) {
        log("Saving geometry for client " + client.resourceClass.toString());

        // save current geometry
        if (config.rememberWindowGeometries) {
            const geometry = {
                "x": client.frameGeometry.x,
                "y": client.frameGeometry.y,
                "width": client.frameGeometry.width,
                "height": client.frameGeometry.height
            };
            if (zones.length > 0) {
                if (getClientZoneTiles(client).length === 0) {
                    client.oldGeometry = geometry;
                }
            }
        }
    }

    function findClosestZone(zones, point, getCenter) {
        let closestZone = null;
        let closestDistance = Infinity;

        for (let i = 0; i < zones.length; i++) {
            const zoneCenter = getCenter(zones[i]);
            const distance = Math.sqrt(Math.pow(point.x - zoneCenter.x, 2) + Math.pow(point.y - zoneCenter.y, 2));
            if (distance < closestDistance) {
                closestZone = i;
                closestDistance = distance;
            }
        }
        return closestZone;
    }

    function moveClientToClosestZone(client) {
        if (!checkFilter(client))
            return null;

        log("Moving client " + client.resourceClass.toString() + " to closest zone");

        refreshClientArea();

        const centerPointOfClient = {
            x: client.frameGeometry.x + (client.frameGeometry.width / 2),
            y: client.frameGeometry.y + (client.frameGeometry.height / 2)
        };

        const layout = getLayout(client.output);
        const closestZone = findClosestZone(layout.zones, centerPointOfClient, zone => ({
                    x: zone.rect.x + zone.rect.width / 2,
                    y: zone.rect.y + zone.rect.height / 2
                }));
        if (closestZone === null)
            return null;

        if (!getClientZone(client, layout).includes(closestZone))
            moveClientToZone(client, [closestZone], layout);
        return closestZone;
    }

    function moveAllClientsToClosestZone() {
        log("Moving all clients to closest zone");
        let count = 0;
        for (let i = 0; i < Workspace.stackingOrder.length; i++) {
            const client = Workspace.stackingOrder[i];
            if (client.move)
                continue;
            moveClientToClosestZone(client) !== null && count++;
        }
        log("Moved " + count + " clients to closest zone");
        return count;
    }

    function getZoneBounds(zones, zoneIndices) {
        // bounding box of zones in percentages of the screen
        let minX = Infinity;
        let minY = Infinity;
        let maxX = -Infinity;
        let maxY = -Infinity;
        zoneIndices.forEach(zoneIndex => {
            const zone = zones[zoneIndex];
            minX = Math.min(minX, zone.x);
            minY = Math.min(minY, zone.y);
            maxX = Math.max(maxX, zone.x + zone.width);
            maxY = Math.max(maxY, zone.y + zone.height);
        });
        return {
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        };
    }

    function findNeighbourZones(zones, bounds, direction, exclude) {
        // zones next to the bounds in a direction, closest first
        // tile edges are floating point percentages
        const epsilon = 0.5;
        const neighbours = [];
        zones.forEach((zone, zoneIndex) => {
            if (exclude.includes(zoneIndex))
                return;
            const overlapsVertically = zone.y < bounds.y + bounds.height - epsilon && zone.y + zone.height > bounds.y + epsilon;
            const overlapsHorizontally = zone.x < bounds.x + bounds.width - epsilon && zone.x + zone.width > bounds.x + epsilon;
            let distance = null;
            switch (direction) {
            case "left":
                if (zone.x + zone.width <= bounds.x + epsilon && overlapsVertically)
                    distance = bounds.x - (zone.x + zone.width);
                break;
            case "right":
                if (zone.x >= bounds.x + bounds.width - epsilon && overlapsVertically)
                    distance = zone.x - (bounds.x + bounds.width);
                break;
            case "up":
                if (zone.y + zone.height <= bounds.y + epsilon && overlapsHorizontally)
                    distance = bounds.y - (zone.y + zone.height);
                break;
            case "down":
                if (zone.y >= bounds.y + bounds.height - epsilon && overlapsHorizontally)
                    distance = zone.y - (bounds.y + bounds.height);
                break;
            }
            if (distance !== null)
                neighbours.push({
                    zoneIndex: zoneIndex,
                    distance: distance
                });
        });
        neighbours.sort((a, b) => a.distance - b.distance || a.zoneIndex - b.zoneIndex);
        return neighbours;
    }

    function adjustClientSpan(client, direction) {
        // like extending a selection with shift+arrows: the zone the span started in stays, the arrows move the opposite edge,
        // so moving away from it grows the span and moving back shrinks it
        if (!checkFilter(client))
            return;

        refreshClientArea();
        const layout = getLayout(client.output);
        const zones = layout.zones;
        const clientZone = getClientZone(client, layout);
        if (clientZone.length === 0) {
            moveClientToClosestZone(client);
            return;
        }

        const indexOf = tile => zones.findIndex(zone => zone.tile === tile);
        let anchor = indexOf(client.spanAdjustAnchor);
        let focus = indexOf(client.spanAdjustFocus);
        // start over when the window was moved or snapped some other way since the last adjustment
        if (anchor === -1 || focus === -1 || getSpanZones(zones, [anchor, focus]).join() !== clientZone.join()) {
            // a span made some other way starts from its top left corner and is adjusted from its bottom right corner
            const bounds = getZoneBounds(zones, clientZone);
            const closestTo = (x, y, corner) => clientZone.slice().sort((a, b) => {
                    const distance = zoneIndex => Math.abs(corner(zones[zoneIndex]).x - x) + Math.abs(corner(zones[zoneIndex]).y - y);
                    return distance(a) - distance(b);
                })[0];
            anchor = closestTo(bounds.x, bounds.y, zone => ({
                        x: zone.x,
                        y: zone.y
                    }));
            focus = closestTo(bounds.x + bounds.width, bounds.y + bounds.height, zone => ({
                        x: zone.x + zone.width,
                        y: zone.y + zone.height
                    }));
        }

        const neighbours = findNeighbourZones(zones, zones[focus], direction, [focus]);
        if (neighbours.length === 0) {
            log("No zone to adjust client " + client.resourceClass.toString() + " " + direction + " into");
            return;
        }
        // with stacked zones next to the edge, move level with the zone the span started in, so moving back retraces the steps
        const isVerticalAxis = direction === "up" || direction === "down";
        const center = zone => isVerticalAxis ? zone.x + zone.width / 2 : zone.y + zone.height / 2;
        const closest = neighbours.filter(neighbour => neighbour.distance <= neighbours[0].distance + 0.5);
        closest.sort((a, b) => Math.abs(center(zones[a.zoneIndex]) - center(zones[anchor])) - Math.abs(center(zones[b.zoneIndex]) - center(zones[anchor])) || a.zoneIndex - b.zoneIndex);
        focus = closest[0].zoneIndex;
        const span = getSpanZones(zones, [anchor, focus]);
        log("Adjusting client " + client.resourceClass.toString() + " " + direction + " to zones " + span);
        client.spanAdjustAnchor = zones[anchor].tile;
        client.spanAdjustFocus = zones[focus].tile;
        moveClientToZone(client, span, layout);
    }

    function moveClientToNeighbour(client, direction) {
        if (!checkFilter(client))
            return null;

        log("Moving client " + client.resourceClass.toString() + " to neighbour " + direction);

        refreshClientArea();

        const layout = getLayout(client.output);
        const zones = layout.zones;
        const clientZone = getClientZone(client, layout);

        if (clientZone.length === 0) {
            moveClientToClosestZone(client);
            return getClientZone(client, layout);
        }
        const currentZone = zones[clientZone[0]];
        const neighbours = findNeighbourZones(zones, currentZone, direction, clientZone);
        const targetZoneIndex = neighbours.length > 0 ? neighbours[0].zoneIndex : -1;
        if (targetZoneIndex !== -1) {
            moveClientToZone(client, [targetZoneIndex], layout);
        } else {
            const toScreenMap = {
                left: "slotWindowToPrevScreen",
                right: "slotWindowToNextScreen",
                up: "slotWindowToAboveScreen",
                down: "slotWindowToBelowScreen"
            };
            if (Workspace[toScreenMap[direction]]) {
                // enter the next screen in the zone mirroring the current one, screens can have different layouts
                const isVerticalAxis = direction === "up" || direction === "down";
                const currentZoneCenter = {
                    x: currentZone.x + currentZone.width / 2,
                    y: currentZone.y + currentZone.height / 2
                };
                const specularPoint = {
                    x: !isVerticalAxis ? (100 - currentZoneCenter.x) : currentZoneCenter.x,
                    y: isVerticalAxis ? (100 - currentZoneCenter.y) : currentZoneCenter.y
                };
                Workspace[toScreenMap[direction]]();
                const targetLayout = getLayout(client.output);
                const specularZone = findClosestZone(targetLayout.zones, specularPoint, zone => ({
                            x: zone.x + zone.width / 2,
                            y: zone.y + zone.height / 2
                        }));
                if (specularZone !== null)
                    moveClientToZone(client, [specularZone], targetLayout);
            }
        }
        return targetZoneIndex;
    }

    function toggleZoneOverlay() {
        if (!config.enableZoneOverlay) {
            osdDbus.exec("Zone overlay is disabled");
        } else if (moving) {
            showZoneOverlay = !showZoneOverlay;
            if (!showZoneOverlay) {
                highlightedZone = [];
                enableSpanning = false;
                spanAnchor = [];
            }
        } else {
            osdDbus.exec("The overlay can only be shown while moving a window");
        }
    }

    function toggleZoneSpanning() {
        if (!showZoneOverlay) {
            toggleZoneOverlay();
        }
        if (moving) {
            enableSpanning = !enableSpanning;
            spanAnchor = enableSpanning ? highlightedZone.slice() : [];
            dwellNeedsLeave = true;
        } else {
            osdDbus.exec("The overlay can only be shown while moving a window");
        }
    }

    function getSpanZones(zones, zoneIndices) {
        // like fancyzones, span the smallest rectangle of zones covering the given zones
        const boundingBox = indices => getZoneGeometry(indices.map(zoneIndex => ({
                        rect: zones[zoneIndex].area
                    })));
        const overlaps = (a, b) => Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x) > 1 && Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y) > 1;
        let box = boundingBox(zoneIndices);
        let span = [];
        // zones that stick out of the box grow it, repeat until it stops growing
        while (true) {
            span = zones.map((zone, zoneIndex) => zoneIndex).filter(zoneIndex => overlaps(zones[zoneIndex].area, box));
            const grown = boundingBox(span);
            if (isSameRect(grown, box))
                break;
            box = grown;
        }
        return span;
    }

    function isHoveringZoneIndicator() {
        // only the indicators start a dwell, so passing over a zone does not
        if (zoneSelector.expanded) {
            return highlightedZone.some(zoneIndex => isHovering(zoneSelector.repeater.itemAt(zoneIndex)));
        }
        if (!config.enableZoneOverlay || !showZoneOverlay)
            return false;
        return highlightedZone.some(zoneIndex => {
            const zoneItem = zoneOverlay.repeater.itemAt(zoneIndex);
            return zoneItem && isHovering(zoneItem.children[0]);
        });
    }

    function canDwell() {
        return config.enableDwellSpanning && moving && shown && !dwellNeedsLeave && highlightedZone.length > 0 && isHoveringZoneIndicator();
    }

    function updateDwell() {
        if (dwellNeedsLeave && !isHoveringZoneIndicator())
            dwellNeedsLeave = false;
        if (!canDwell()) {
            stopDwell();
            return;
        }
        // small movements while holding still are allowed, while spanning the dwell turns it off again
        const cursorPos = Workspace.cursorPos;
        if (!dwellPoint || Math.abs(cursorPos.x - dwellPoint.x) > 8 || Math.abs(cursorPos.y - dwellPoint.y) > 8 || dwellIndicator.reversed !== enableSpanning) {
            dwellPoint = {
                x: cursorPos.x,
                y: cursorPos.y
            };
            dwellIndicator.restart(enableSpanning);
        }
    }

    function stopDwell() {
        dwellPoint = null;
        dwellIndicator.stop();
    }

    function finishDwell() {
        if (!canDwell())
            return;
        if (enableSpanning) {
            log("Dwell finished, spanning stopped");
            enableSpanning = false;
            spanAnchor = [];
        } else {
            log("Dwell finished, spanning from zones " + highlightedZone);
            if (!showZoneOverlay)
                toggleZoneOverlay();
            enableSpanning = true;
            spanAnchor = highlightedZone.slice();
        }
        dwellNeedsLeave = true;
        stopDwell();
    }

    function snapshotLayout(tile) {
        let rootTile = tile;
        while (rootTile.parent)
            rootTile = rootTile.parent;
        const snapshot = [];
        const visit = t => {
            const g = t.relativeGeometry;
            snapshot.push({
                tile: t,
                geometry: Qt.rect(g.x, g.y, g.width, g.height)
            });
            t.tiles.forEach(visit);
        };
        visit(rootTile);
        return snapshot;
    }

    function restoreLayout(snapshot) {
        // neighbouring tiles adjust each other, so a second pass settles any edge the first one moved
        for (let pass = 0; pass < 2; pass++) {
            snapshot.forEach(entry => {
                const g = entry.tile.relativeGeometry;
                // relative geometry is a fraction of the screen
                if (!g || (Math.abs(g.x - entry.geometry.x) < 1e-6 && Math.abs(g.y - entry.geometry.y) < 1e-6 && Math.abs(g.width - entry.geometry.width) < 1e-6 && Math.abs(g.height - entry.geometry.height) < 1e-6))
                    return;
                log("Restoring tile geometry " + JSON.stringify(entry.geometry));
                entry.tile.relativeGeometry = entry.geometry;
            });
        }
    }

    function disconnectSignals(client) {
        const handlers = client.fancyKZonesHandlers;
        if (!handlers)
            return;
        try {
            client.onInteractiveMoveResizeStarted.disconnect(handlers.started);
            client.onInteractiveMoveResizeStepped.disconnect(handlers.stepped);
            client.onInteractiveMoveResizeFinished.disconnect(handlers.finished);
            client.onFullScreenChanged.disconnect(handlers.fullScreen);
        } catch (e) {
            // already disconnected
        }
        client.fancyKZonesHandlers = null;
    }

    function connectSignals(client) {
        if (!checkFilter(client))
            return;

        log("Connecting signals for client " + client.resourceClass.toString());

        // kwin shares one qml engine between scripts, so handlers from a previous load are still connected
        disconnectSignals(client);
        client.fancyKZonesHandlers = {
            started: onInteractiveMoveResizeStarted,
            stepped: onInteractiveMoveResizeStepped,
            finished: onInteractiveMoveResizeFinished,
            fullScreen: onFullScreenChanged
        };
        client.onInteractiveMoveResizeStarted.connect(onInteractiveMoveResizeStarted);
        client.onInteractiveMoveResizeStepped.connect(onInteractiveMoveResizeStepped);
        client.onInteractiveMoveResizeFinished.connect(onInteractiveMoveResizeFinished);
        client.onFullScreenChanged.connect(onFullScreenChanged);

        function onInteractiveMoveResizeStarted() {
            log("Interactive move/resize started for client " + client.resourceClass.toString());
            if (client.resizeable && checkFilter(client)) {
                if (client.move && checkFilter(client)) {
                    if (config.fadeWindowsWhileMoving) {
                        for (let i = 0; i < Workspace.stackingOrder.length; i++) {
                            const client = Workspace.stackingOrder[i];
                            client.previousOpacity = client.opacity;
                            if (client.move || !client.normalWindow)
                                continue;
                            client.opacity = 0.5;
                        }
                    }

                    const zoneTiles = getClientZoneTiles(client);
                    if (zoneTiles.length > 0) {
                        const frameGeometry = Qt.rect(client.frameGeometry.x, client.frameGeometry.y, client.frameGeometry.width, client.frameGeometry.height);
                        const managed = isCustomTile(client.tile);
                        // take the window out of its tile, the drop decides where it goes next
                        if (managed) {
                            unmanageClient(client);
                            setZoneTiles(client, zoneTiles);
                        }

                        if (config.rememberWindowGeometries && client.oldGeometry) {
                            const geometry = client.oldGeometry;
                            const newGeometry = Qt.rect(Math.round(Workspace.cursorPos.x - geometry.width / 2), Math.round(frameGeometry.y), Math.round(geometry.width), Math.round(geometry.height));
                            client.frameGeometry = newGeometry;
                        } else if (managed && !config.rememberWindowGeometries) {
                            // kwin restores the geometry from before tiling, keep the zone size instead
                            client.frameGeometry = frameGeometry;
                        }
                    }

                    moving = true;
                    moved = false;
                    resizing = false;
                    log("Move start " + client.resourceClass.toString());
                    mainDialog.show();
                }
                if (client.resize) {
                    // resizing a tiled window moves the tile edges for every window, only resize the window itself like fancyzones
                    if (isCustomTile(client.tile)) {
                        const tile = client.tile;
                        const frameGeometry = Qt.rect(client.frameGeometry.x, client.frameGeometry.y, client.frameGeometry.width, client.frameGeometry.height);
                        layoutSnapshot = snapshotLayout(tile);
                        unmanageClient(client);
                        // kwin restores the geometry from before tiling, keep the zone size instead
                        client.frameGeometry = frameGeometry;
                        setZoneTiles(client, [tile]);
                    }
                    moving = false;
                    moved = false;
                    resizing = true;
                }
            }
        }

        function onInteractiveMoveResizeStepped() {
            if (client.resizeable) {
                if (moving && checkFilter(client)) {
                    moved = true;
                }
            }
        }

        function onInteractiveMoveResizeFinished() {
            log("Interactive move/resize finished for client " + client.resourceClass.toString());

            if (config.fadeWindowsWhileMoving) {
                for (let i = 0; i < Workspace.stackingOrder.length; i++) {
                    const client = Workspace.stackingOrder[i];
                    client.opacity = client.previousOpacity || 1;
                }
            }

            if (moving) {
                log("Move end " + client.resourceClass.toString());
                if (moved) {
                    if (shown) {
                        moveClientToZone(client, highlightedZone, currentLayout);
                    } else {
                        setZoneTiles(client, []);
                    }
                }
                hide();
            } else if (resizing) {
                // stop following the tile first, putting the layout back would snap the window to the tile again
                setZoneTiles(client, []);
                // kwin may still have moved tile edges before the window left its tile
                restoreLayout(layoutSnapshot);
                layoutSnapshot = [];
                matchZone(client);
                // still exactly in its zone, for example when the resize was cancelled, so hand it back to kwin
                if (!isCustomTile(client.tile) && client.zoneTiles.length === 1 && manageClient(client.zoneTiles[0], client))
                    setZoneTiles(client, []);
                log("Resizing end: Matched client " + client.resourceClass.toString() + " to zone " + getClientZone(client, getLayout(client.output)));
            }
            moving = false;
            moved = false;
            resizing = false;
        }

        function onFullScreenChanged() {
            log("Client fullscreen: " + client.resourceClass.toString() + " (fullscreen " + client.fullScreen + ")");
            mainDialog.hide();
        }
    }

    Components.ColorHelper {
        id: colorHelper
    }

    Components.Shortcuts {
        onMoveActiveWindowToNextZone: {
            const client = Workspace.activeWindow;
            if (!checkFilter(client))
                return;
            const layout = getLayout(client.output);
            if (layout.zones.length === 0)
                return;
            if (getClientZone(client, layout).length === 0)
                moveClientToClosestZone(client);
            const zone = getClientZone(client, layout);
            const primary = (zone.length > 0) ? zone[0] : 0;
            moveClientToZone(client, [(primary + 1) % layout.zones.length], layout);
        }

        onMoveActiveWindowToPreviousZone: {
            const client = Workspace.activeWindow;
            if (!checkFilter(client))
                return;
            const layout = getLayout(client.output);
            if (layout.zones.length === 0)
                return;
            if (getClientZone(client, layout).length === 0)
                moveClientToClosestZone(client);
            const zone = getClientZone(client, layout);
            const primary = (zone.length > 0) ? zone[0] : 0;
            moveClientToZone(client, [(primary - 1 + layout.zones.length) % layout.zones.length], layout);
        }

        onToggleZoneOverlay: {
            mainDialog.toggleZoneOverlay();
        }

        onToggleZoneSpanning: {
            mainDialog.toggleZoneSpanning();
        }

        onSwitchToNextWindowInCurrentZone: {
            if (!Workspace.activeWindow)
                return;
            const zoneTiles = getClientZoneTiles(Workspace.activeWindow);
            if (zoneTiles.length > 0)
                switchWindowInZone(zoneTiles[0]);
        }

        onSwitchToPreviousWindowInCurrentZone: {
            if (!Workspace.activeWindow)
                return;
            const zoneTiles = getClientZoneTiles(Workspace.activeWindow);
            if (zoneTiles.length > 0)
                switchWindowInZone(zoneTiles[0], true);
        }

        onMoveActiveWindowToZone: zone => {
            const client = Workspace.activeWindow;
            if (!checkFilter(client))
                return;
            const layout = getLayout(client.output);
            if (zone < layout.zones.length) {
                moveClientToZone(client, [zone], layout);
            } else {
                osdDbus.exec(`Zone ${zone + 1} does not exist`);
            }
        }

        onMoveActiveWindowUp: {
            moveClientToNeighbour(Workspace.activeWindow, "up");
        }

        onMoveActiveWindowDown: {
            moveClientToNeighbour(Workspace.activeWindow, "down");
        }

        onMoveActiveWindowLeft: {
            moveClientToNeighbour(Workspace.activeWindow, "left");
        }

        onMoveActiveWindowRight: {
            moveClientToNeighbour(Workspace.activeWindow, "right");
        }

        onAdjustActiveWindowSpan: direction => {
            adjustClientSpan(Workspace.activeWindow, direction);
        }

        onSnapActiveWindow: {
            moveClientToClosestZone(Workspace.activeWindow);
        }

        onSnapAllWindows: {
            moveAllClientsToClosestZone();
        }

        onRestoreActiveWindow: {
            restoreClientGeometry(Workspace.activeWindow);
        }
    }

    Component.onCompleted: {
        mainDialog.loadConfig();
        // refresh client area
        refreshClientArea();

        // match all clients to zones and connect signals
        for (let i = 0; i < Workspace.stackingOrder.length; i++) {
            matchZone(Workspace.stackingOrder[i]);
            connectSignals(Workspace.stackingOrder[i]);
        }

        // without compositing on x11 an invisible window can't be shown, it would flash
        if (Qt.platform.pluginName.startsWith("wayland"))
            warmUpTimer.start();
    }

    function finishWarmUp() {
        if (!warmingUp)
            return;
        warmingUp = false;
        warmUpFallback.stop();
        // a drag that started meanwhile keeps the overlay, as it would normally show
        if (moving)
            showZoneOverlay = config.zoneOverlayShowWhen == 0;
        else
            hide();
        mainDialog.opacity = 1;
        log("Overlay warmed up");
    }

    Component.onDestruction: {
        // the qml engine outlives the script, so leave nothing connected when the script is unloaded
        for (let i = 0; i < Workspace.stackingOrder.length; i++) {
            const client = Workspace.stackingOrder[i];
            disconnectSignals(client);
            setZoneTiles(client, []);
        }
    }

    Item {
        id: mainItem
        width: mainDialog.width
        height: mainDialog.height

        // main polling timer
        Timer {
            id: timer

            triggeredOnStart: true
            interval: config.pollingRate
            running: shown && moving
            repeat: true

            onTriggered: {
                refreshClientArea();

                let hoveringZone = [];
                const zones = currentLayout.zones;

                // zone overlay
                if (config.enableZoneOverlay && showZoneOverlay && !zoneSelector.expanded) {
                    zones.forEach((zone, zoneIndex) => {
                        const zoneItem = zoneOverlay.repeater.itemAt(zoneIndex);
                        if (zoneItem && isHovering(zoneItem.children[config.zoneOverlayHighlightTarget])) {
                            hoveringZone = [zoneIndex];
                        }
                    });
                }

                // zone selector
                if (config.enableZoneSelector) {
                    if (!zoneSelector.animating && zoneSelector.expanded) {
                        zones.forEach((zone, zoneIndex) => {
                            if (isHovering(zoneSelector.repeater.itemAt(zoneIndex))) {
                                hoveringZone = [zoneIndex];
                            }
                        });
                    }
                    // set zoneSelector expansion state
                    zoneSelector.expanded = isHovering(zoneSelector) && (Workspace.cursorPos.y - clientArea.y) >= 0;
                    // set zoneSelector near state
                    const triggerDistance = config.zoneSelectorTriggerDistance * 50 + 25;
                    zoneSelector.near = (Workspace.cursorPos.y - clientArea.y) < zoneSelector.y + zoneSelector.height + triggerDistance;
                }

                // edge snapping
                if (config.enableEdgeMode === 1) {
                    const triggerDistance = (config.edgeSnappingTriggerDistance + 1) * 10;
                    if (Workspace.cursorPos.x <= clientArea.x + triggerDistance || Workspace.cursorPos.x >= clientArea.x + clientArea.width - triggerDistance || Workspace.cursorPos.y <= clientArea.y + triggerDistance || Workspace.cursorPos.y >= clientArea.y + clientArea.height - triggerDistance) {
                        zones.forEach((zone, zoneIndex) => {
                            // tiles end at the panels, stretch the outer ones to the screen edge
                            let left = zone.area.x;
                            let top = zone.area.y;
                            let right = zone.area.x + zone.area.width;
                            let bottom = zone.area.y + zone.area.height;
                            if (zone.x <= 0.01)
                                left = clientArea.x;
                            if (zone.y <= 0.01)
                                top = clientArea.y;
                            if (zone.x + zone.width >= 99.99)
                                right = clientArea.x + clientArea.width;
                            if (zone.y + zone.height >= 99.99)
                                bottom = clientArea.y + clientArea.height;
                            if (isPointInside(Workspace.cursorPos.x, Workspace.cursorPos.y, {
                                x: left,
                                y: top,
                                width: right - left,
                                height: bottom - top
                            })) {
                                hoveringZone = [zoneIndex];
                            }
                        });
                    }
                } else if (config.enableEdgeMode === 2) {
                    const triggerDistance = (config.edgeSnappingTriggerDistance + 1) * 10;
                    if (Workspace.cursorPos.x <= clientArea.x + triggerDistance || Workspace.cursorPos.x >= clientArea.x + clientArea.width - triggerDistance || Workspace.cursorPos.y <= clientArea.y + triggerDistance || Workspace.cursorPos.y >= clientArea.y + clientArea.height - triggerDistance) {
                        if (!enteredEdge) {
                            toggleZoneOverlay();
                            // the span starts from the first zone hovered after the bump
                            if (config.bumpStartsSpanning && showZoneOverlay && !enableSpanning) {
                                log("Bump started spanning");
                                enableSpanning = true;
                                spanAnchor = [];
                                dwellNeedsLeave = true;
                            }
                            enteredEdge = true;
                        }
                    } else {
                        enteredEdge = false;
                    }
                }

                // zone spanning detection
                if (showZoneOverlay && config.zoneSpanningDistance && config.zoneSpanningDistance > 0) {
                    const span = config.zoneSpanningDistance;
                    const halfSpan = span / 2;
                    const expandedMatches = [];
                    zones.forEach((zone, zoneIndex) => {
                        let zoneGeometry = {
                            x: zone.rect.x - halfSpan,
                            y: zone.rect.y - halfSpan,
                            width: zone.rect.width + span,
                            height: zone.rect.height + span
                        };
                        // clamp to client area
                        if (zoneGeometry.x < clientArea.x) {
                            zoneGeometry.width -= (clientArea.x - zoneGeometry.x);
                            zoneGeometry.x = clientArea.x;
                        }
                        if (zoneGeometry.y < clientArea.y) {
                            zoneGeometry.height -= (clientArea.y - zoneGeometry.y);
                            zoneGeometry.y = clientArea.y;
                        }
                        if (zoneGeometry.x + zoneGeometry.width > clientArea.x + clientArea.width) {
                            zoneGeometry.width = clientArea.x + clientArea.width - zoneGeometry.x;
                        }
                        if (zoneGeometry.y + zoneGeometry.height > clientArea.y + clientArea.height) {
                            zoneGeometry.height = clientArea.y + clientArea.height - zoneGeometry.y;
                        }
                        if (isPointInside(Workspace.cursorPos.x, Workspace.cursorPos.y, zoneGeometry)) {
                            expandedMatches.push(zoneIndex);
                        }
                    });
                    if (expandedMatches.length >= 2) {
                        hoveringZone = expandedMatches;
                    }
                }
                // if hovering zone changed from the last frame
                if (enableSpanning) {
                    if (spanAnchor.length === 0)
                        spanAnchor = hoveringZone.slice();
                    if (spanAnchor.length > 0 && hoveringZone.length > 0) {
                        const spanZones = getSpanZones(zones, spanAnchor.concat(hoveringZone));
                        if (spanZones.join() !== highlightedZone.join()) {
                            log("Highlighting zones " + spanZones + " in layout " + currentLayout.key);
                            highlightedZone = spanZones;
                        }
                    }
                } else if (hoveringZone.join() !== highlightedZone.join()) {
                    log("Highlighting zones " + hoveringZone + " in layout " + currentLayout.key);
                    highlightedZone = hoveringZone.slice().sort((a, b) => a - b);
                }

                // the cursor may be held perfectly still, so the dwell is also checked here
                updateDwell();
            }
        }

        DBusCall {
            id: osdDbus

            service: "org.kde.plasmashell"
            path: "/org/kde/osdService"
            method: "showText"

            function exec(text, icon = "preferences-desktop-virtual") {
                if (!config.showOsdMessages)
                    return;
                this.arguments = [icon, text];
                this.call();
            }
        }

        Item {
            x: clientArea.x || 0
            y: clientArea.y || 0
            width: clientArea.width || 0
            height: clientArea.height || 0
            clip: true

            Components.Debug {
                info: ({
                        activeWindow: {
                            caption: Workspace.activeWindow?.caption,
                            resourceClass: Workspace.activeWindow?.resourceClass?.toString(),
                            frameGeometry: {
                                x: Workspace.activeWindow?.frameGeometry?.x,
                                y: Workspace.activeWindow?.frameGeometry?.y,
                                width: Workspace.activeWindow?.frameGeometry?.width,
                                height: Workspace.activeWindow?.frameGeometry?.height
                            },
                            zone: Workspace.activeWindow ? getClientZone(Workspace.activeWindow, currentLayout) : [],
                            managedByKWin: isCustomTile(Workspace.activeWindow?.tile)
                        },
                        highlightedZone: mainDialog.highlightedZone,
                        moving: moving,
                        resizing: resizing,
                        oldGeometry: Workspace.activeWindow?.oldGeometry,
                        activeScreen: activeScreen?.name,
                        currentLayout: currentLayout.key,
                        zones: currentLayout.zones.length
                    })
                errors: mainDialog.errors
                config: mainDialog.config
            }

            Components.Zones {
                id: zoneOverlay
                config: mainDialog.config
                layoutZones: mainDialog.currentLayout.zones
                aspectRatio: mainDialog.currentLayout.aspectRatio || 16 / 9
                highlightedZone: mainDialog.highlightedZone
                spanning: mainDialog.enableSpanning
                spanAnchor: mainDialog.spanAnchor
                area: mainDialog.clientArea
            }

            Components.Selector {
                id: zoneSelector
                config: mainDialog.config
                layoutZones: mainDialog.currentLayout.zones
                aspectRatio: mainDialog.currentLayout.aspectRatio || 16 / 9
                highlightedZone: mainDialog.highlightedZone
                spanning: mainDialog.enableSpanning
                spanAnchor: mainDialog.spanAnchor
            }
        }

        Components.DwellIndicator {
            id: dwellIndicator
            duration: config.dwellSpanningDelay || 600
            x: Workspace.cursorPos.x - width / 2
            y: Workspace.cursorPos.y - height / 2
            onDwellFinished: finishDwell()
        }

        // workspace connection
        Connections {
            target: Workspace

            function onCursorPosChanged() {
                if (moving && shown)
                    updateDwell();
            }

            function onWindowAdded(client) {
                connectSignals(client);

                // auto snap to closest zone
                if (config.autoSnapAllNew && checkFilter(client)) {
                    moveClientToClosestZone(client);
                }

                // check if new window spawns in a zone
                if (getClientZoneTiles(client).length === 0)
                    matchZone(client);
            }

            function onWindowRemoved(client) {
                setZoneTiles(client, []);
            }
        }

        // options connection
        Connections {
            //! not working at the moment
            target: Options

            function onConfigChanged() {
                log("Config changed");
                mainDialog.loadConfig();
            }
        }

        // the first time the overlay is shown its window and graphics are set up, which makes the first drag stall
        // show it once invisibly shortly after login instead, the graphics stay set up after hiding it
        Timer {
            id: warmUpTimer
            interval: 3000
            onTriggered: {
                if (moving || shown)
                    return;
                warmingUp = true;
                mainDialog.opacity = 0;
                // render the indicators as well, so their effects are set up too
                showZoneOverlay = true;
                mainDialog.show();
                warmUpFallback.start();
            }
        }

        // in case no frame is drawn
        Timer {
            id: warmUpFallback
            interval: 1000
            onTriggered: finishWarmUp()
        }

        Connections {
            target: mainDialog
            function onFrameSwapped() {
                if (mainDialog.warmingUp)
                    finishWarmUp();
            }
        }

        // reusable timer
        Timer {
            id: delay

            function setTimeout(callback, timeout) {
                delay.interval = timeout;
                delay.repeat = false;
                delay.triggered.connect(callback);
                delay.triggered.connect(function release() {
                    delay.triggered.disconnect(callback);
                    delay.triggered.disconnect(release);
                });
                delay.start();
            }
        }
    }
}
