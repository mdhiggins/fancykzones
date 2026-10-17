# Contributing

## Code Formatting

### QML

QML files are formatted with `qmlformat` from Qt 6.11, using its default settings.

```bash
qmlformat -i path/to/file.qml
```

If Qt's development tools are not installed, `qmlformat` is also included in the `PySide6-Essentials` Python package.

## Upstream

FancyKZones is a fork of [KZones](https://github.com/gerritdevriese/kzones). Upstream changes are reviewed and ported by hand, since zones work differently here.

Last reviewed upstream commit: `353570a` (Always render active zone in indicator on top). To see what changed since then:

```bash
git remote add upstream https://github.com/gerritdevriese/kzones.git
git fetch upstream
git log 353570a..upstream/main
```

## Development Resources

### API Documentation

- [KDE Frameworks API reference](https://api.kde.org/)
- [Kirigami style colors](https://develop.kde.org/docs/getting-started/kirigami/style-colors/)
- [KWin scripting API](https://develop.kde.org/docs/plasma/kwin/api/)

### Examples and source code

- [Example KWin scripts](https://invent.kde.org/plasma/kwin/-/tree/master/src/plugins)
- [KWin scripting API source code](https://invent.kde.org/plasma/kwin/-/tree/master/src/scripting)
- [KWin tiling source code](https://invent.kde.org/plasma/kwin/-/tree/master/src/tiles), zones come from these tiles

## KWin debugging

Script configurations are saved inside: `~/.config/kwinrc`

Live script code is stored here: `~/.local/share/kwin/scripts`

Run nested kwin: `dbus-run-session startplasma-wayland`

Run a headless kwin that does not touch your session or settings, then load the script into it over its own D-Bus session:

```sh
XDG_CONFIG_HOME=/tmp/fancykzones-test dbus-run-session -- sh -c '
    kwin_wayland --virtual --no-lockscreen --width 1920 --height 1080 --socket wayland-test &
    sleep 4
    dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.loadDeclarativeScript string:"$(realpath src/contents/ui/main.qml)" string:fancykzones-test
    dbus-send --session --print-reply --dest=org.kde.KWin /Scripting org.kde.kwin.Scripting.start
    WAYLAND_DISPLAY=wayland-test kwrite'
```

Shortcuts can be triggered from the same session with `dbus-send --session --dest=org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut string:"FancyKZones: Snap active window"`.

## Tips

- You can edit the configuration UI (`src/contents/ui/config.ui`) using [Qt Widgets Designer](https://doc.qt.io/qt-6/qtdesigner-manual.html), which is part of the Qt development tools.
- The makefile contains some handy commands to test and run the script, either by loading it directly or in a nested Plasma session, run `make help` to list them.
- KWin caches the QML of a script by path until KWin restarts, so reinstalling and reloading the installed script keeps running the old code. `make reload` loads the source from a new temporary path every time, disable the installed script first so they don't both run.
- Script paths have to be canonical, on systems where `/home` is a symlink (like Fedora Atomic) use `realpath`, otherwise the script fails with "File name case mismatch".
