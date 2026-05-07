import QtQuick
import QtCore

Item {
    visible: false

    Settings {
        id: s
        category: "appearance"
        property int themeMode: 0
    }

    property int mode: s.themeMode
    onModeChanged: s.themeMode = mode

    readonly property bool dark: mode === 0

    // ── Fondos ──────────────────────────────────────────
    readonly property color bgBase:        dark ? "#0f1117" : "#f4f5f7"
    readonly property color bgSurface:     dark ? "#16181f" : "#ffffff"
    readonly property color bgSurface2:    dark ? "#1c1e27" : "#ecedf1"
    readonly property color bgSidebar:     dark ? "#0c0d12" : "#111318"
    readonly property color bgHeader:      dark ? "#12141a" : "#111318"
    readonly property color bgInput:       dark ? "#1a1c24" : "#f0f1f5"

    // ── Bordes ──────────────────────────────────────────
    readonly property color border:        dark ? "#262830" : "#d8dae0"
    readonly property color borderAccent:  dark ? "#3d9be9" : "#2b7fd4"

    // ── Texto ───────────────────────────────────────────
    readonly property color textPrimary:   dark ? "#e8eaed" : "#1a1c22"
    readonly property color textSecondary: dark ? "#9ba1ad" : "#52566a"
    readonly property color textMuted:     dark ? "#5c6170" : "#888da0"
    readonly property color textOnDark:    "#e8eaed"
    readonly property color textMutedOnDark: "#6b7080"

    // ── Acento ──────────────────────────────────────────
    readonly property color accent:        dark ? "#3d9be9" : "#2b7fd4"
    readonly property color accentLight:   dark ? "#5bb4f5" : "#1a6dc0"
    readonly property color accentSoft:    dark ? "#1a2e42" : "#e0f0ff"

    // ── Estados ─────────────────────────────────────────
    readonly property color success:       dark ? "#34d399" : "#0f8a5f"
    readonly property color successBg:     dark ? "#0d2318" : "#dcf5ea"
    readonly property color successBadge:  dark ? "#166534" : "#15803d"
    readonly property color error:         "#f06050"
    readonly property color errorBg:       dark ? "#3b1418" : "#fde8e8"
    readonly property color warning:       dark ? "#f5a524" : "#c77c00"
    readonly property color warningBg:     dark ? "#2d1f08" : "#fef3d6"

    // ── Tarjetas ────────────────────────────────────────
    readonly property color cardBg:        dark ? "#16181f" : "#ffffff"
    readonly property color cardBorder:    dark ? "#22252e" : "#e0e2e8"
    readonly property color cardHover:     dark ? "#1e2029" : "#f6f7fa"

    // ── Overlay ─────────────────────────────────────────
    readonly property color overlay:       dark ? "#cc0a0b10" : "#80000000"

    // ── Utilidades ──────────────────────────────────────
    readonly property int   radiusSm:      6
    readonly property int   radiusMd:      10
    readonly property int   radiusLg:      14
}
