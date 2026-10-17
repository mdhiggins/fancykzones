# Changelog

## 1.1.1

### Fixed

- The span animation in the zone indicators no longer stutters when the highlighted indicator grows at the same time.

## 1.1.0

### New

- **Span windows with the keyboard.** <kbd>Meta</kbd> + <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + arrow keys adjusts the span of the active window, like FancyZones. The zone it started in stays put, pressing away from it grows the span and pressing back shrinks it again. ([#2](https://github.com/mdhiggins/FancyKZones/issues/2))
- **Bumping can start zone spanning.** A new option under Edge Snapping / Bumping starts spanning straight away when a bump shows the overlay, from the first zone you move over. Off by default.
- **Adjacent zones merge in the indicators.** When a window is dropped near the border between zones, the indicators show those zones as one merged block, the same as spanning.

### Improved

- **Indicators match your monitor.** The zone indicators now take the aspect ratio of the screen they are on, so ultrawide and portrait layouts are no longer squashed into 16:9.
- **Clearer indicators.** Each indicator shows its zone in the accent color only when the window will be placed in it, other indicators show a muted version. The accent border now marks those zones too, spanning is shown by the chain link badge.
- **Sharper indicators.** Zone edges are aligned to whole pixels, and the highlighted indicator grows by resizing instead of scaling, so indicators no longer look blurry, especially on wide screens.
- **Smoother span animation.** The merged block always grows out of and shrinks back into its zone, instead of sometimes flying in from the corner.
- **No more stall on the first drag.** The overlay is now prepared shortly after login, so the first window you drag no longer freezes for a moment.
- The Layouts tab in the settings is now laid out like the Shortcuts tab.

### Fixed

- Resizing a window snapped into a single zone no longer snaps it back to the zone size on the first attempt.

### Notes

- <kbd>Meta</kbd> + <kbd>Arrows</kbd> is also used by KWin's own Quick Tile shortcuts, which snap windows to halves and quarters of the screen instead of your zones. The README now explains how to free it for moving windows between zones.

## 1.0.0

First release as FancyKZones, a fork of [KZones](https://github.com/gerritdevriese/kzones) by gerritdevriese.

- **Zones from KDE Plasma's tiling layouts.** Layouts are edited with <kbd>Meta</kbd> + <kbd>T</kbd> instead of JSON, every screen and virtual desktop has its own layout. A window snapped into a single zone is tiled by KWin itself.
- **Zone spanning.** Drop a window across multiple zones. Spans are the smallest rectangle of zones covering the zone you started from and the zone under the cursor, like FancyZones.
- **Mouse-only controls.** Hold the cursor still on a zone indicator to start or stop spanning, bump a window into the screen edge to show the overlay, or drop it near the border between zones to span both.
- **Spanning visuals.** The indicators show the span as one merged block with a dot on the starting zone, and a chain link badge while spanning.
- **Spanned windows follow the layout.** Windows covering multiple zones move along when tiles are resized in the tile editor.
- **Resizing only resizes the window.** Resizing a snapped window no longer moves the tile edges for every window.
- **Restore shortcut.** <kbd>Meta</kbd> + <kbd>Backspace</kbd> restores the active window to its size from before it was snapped (from KZones).
- Removed JSON layouts, layout cycling, the activate layout shortcuts, tracking the layout per screen and the per-zone `applications`, `color` and `indicator` options, as layouts now come from KWin.
