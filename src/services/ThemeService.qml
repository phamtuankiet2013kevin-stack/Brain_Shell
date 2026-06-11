pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../"

// ============================================================
// ThemeService — premade theme presets + apply pipeline
//
// Presets live in src/config/themes/presets.json (shipped).
// User selection persists to src/user_data/theme.json.
//
// Apply flow:
//   wallpaper present on disk → WallpaperService.apply() + matugen
//   wallpaper missing         → write static colors to colors.json
// ============================================================

QtObject {
    id: root

    readonly property string presetsPath: Quickshell.shellDir + "/src/config/themes/presets.json"
    readonly property string configPath:  Quickshell.env("HOME") + "/.config/Brain_Shell/src/user_data/theme.json"
    readonly property string colorsPath:  Quickshell.env("HOME") + "/.cache/brain-shell/colors.json"

    property var    themes:         []
    property string currentThemeId: ""
    property bool   applying:       false

    signal themeApplied(string id)

    function themeById(id) {
        for (var i = 0; i < root.themes.length; i++)
            if (root.themes[i].id === id) return root.themes[i]
        return null
    }

    function resolveWallpaper(theme) {
        if (!theme || !theme.wallpaper || theme.wallpaper === "") return ""
        if (theme.wallpaper.indexOf("/") === 0) return theme.wallpaper
        return Quickshell.shellDir + "/" + theme.wallpaper
    }

    function applyTheme(id) {
        if (root.applying || id === "") return
        var theme = root.themeById(id)
        if (!theme) return

        root.applying = true
        root.currentThemeId = id

        var wallPath = root.resolveWallpaper(theme)
        checkWallProc.themeId  = id
        checkWallProc.theme    = theme
        checkWallProc.command  = [
            "bash", "-c",
            "test -f \"" + wallPath + "\" && echo yes || echo no"
        ]
        checkWallProc.running = true
    }

    function saveConfig() {
        var json = JSON.stringify({ currentThemeId: root.currentThemeId })
        saveConfigProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.configPath + "'"
        ]
        saveConfigProc.running = true
    }

    function _applyStaticColors(theme) {
        var colors = theme.colors || {}
        var json = JSON.stringify({
            background: colors.background || "#1a282a",
            active:     colors.active     || "#a6d0f7",
            text:       colors.text       || "#cdd6f4",
            subtext:    colors.subtext    || "#94e2d5",
            border:     colors.border     || "#45475a",
            iconFont:   colors.iconFont   || "#2f8d97"
        })
        writeColorsProc.themeId = theme.id
        writeColorsProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.colorsPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.colorsPath + "'"
        ]
        writeColorsProc.running = true
    }

    function _applyWithWallpaper(theme, wallPath) {
        if (theme.scheme && theme.scheme !== "")
            WallpaperService.scheme = theme.scheme
        _pendingThemeId = theme.id
        WallpaperService.apply(wallPath)
    }

    property string _pendingThemeId: ""

    property var checkWallProc: Process {
        property string themeId: ""
        property var    theme:   null
        property string _result: ""

        command: []
        stdout: SplitParser {
            onRead: function(line) { checkWallProc._result = line.trim() }
        }
        onExited: function() {
            if (_result === "yes")
                root._applyWithWallpaper(theme, root.resolveWallpaper(theme))
            else
                root._applyStaticColors(theme)
            _result = ""
        }
    }

    property var writeColorsProc: Process {
        property string themeId: ""
        onExited: function(exitCode) {
            root.applying = false
            if (exitCode === 0) {
                borderTimer.restart()
                root.saveConfig()
                root.themeApplied(themeId)
            }
        }
    }

    property var saveConfigProc: Process {}

    Timer {
        id: borderTimer
        interval: 80
        onTriggered: WallpaperService.updateBorders()
    }

    Connections {
        target: WallpaperService
        function onWallpaperApplied(path) {
            if (root._pendingThemeId === "") return
            root.applying = false
            root.currentThemeId = root._pendingThemeId
            var appliedId = root._pendingThemeId
            root._pendingThemeId = ""
            root.saveConfig()
            root.themeApplied(appliedId)
        }

        function onWallpaperApplyFailed(path) {
            if (root._pendingThemeId === "") return
            var theme = root.themeById(root._pendingThemeId)
            root._pendingThemeId = ""
            if (theme) root._applyStaticColors(theme)
            else root.applying = false
        }
    }

    property string _presetsBuf: ""
    property var loadPresetsProc: Process {
        command: ["bash", "-c", "cat '" + root.presetsPath + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) { root._presetsBuf += line }
        }
        onExited: function() {
            if (root._presetsBuf !== "") {
                try {
                    var obj = JSON.parse(root._presetsBuf)
                    if (obj.themes && obj.themes.length > 0)
                        root.themes = obj.themes
                } catch (e) {}
            }
            readConfigProc.running = true
        }
    }

    property string _cfgBuf: ""
    property var readConfigProc: Process {
        command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
        stdout: SplitParser {
            onRead: function(line) { root._cfgBuf += line }
        }
        onExited: function() {
            if (root._cfgBuf !== "") {
                try {
                    var obj = JSON.parse(root._cfgBuf)
                    if (obj.currentThemeId && obj.currentThemeId !== "")
                        root.currentThemeId = obj.currentThemeId
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: loadPresetsProc.running = true
}
