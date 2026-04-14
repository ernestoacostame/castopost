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

    // ── Fondos ────────────────────────────────────────────
    readonly property color bgBase:        dark ? "#13132a" : "#eef0f8"
    readonly property color bgSurface:     dark ? "#1e1e3a" : "#ffffff"
    readonly property color bgSurface2:    dark ? "#25254a" : "#e2e5f5"
    readonly property color bgSidebar:     dark ? "#1a1a2e" : "#2a1f6e"  // sidebar siempre oscuro
    readonly property color bgHeader:      dark ? "#1a1a35" : "#2a1f6e"  // header igual
    readonly property color bgInput:       dark ? "#12122a" : "#f5f6ff"

    // ── Bordes ────────────────────────────────────────────
    readonly property color border:        dark ? "#33334a" : "#c8cce8"
    readonly property color borderAccent:  "#7c4dff"

    // ── Texto ─────────────────────────────────────────────
    readonly property color textPrimary:   dark ? "#e0e0ff" : "#12103a"
    readonly property color textSecondary: dark ? "#9090b0" : "#3a3860"
    readonly property color textMuted:     dark ? "#666688" : "#6860a0"
    // Texto sobre sidebar/header oscuro (siempre blanco)
    readonly property color textOnDark:    "#e0e0ff"
    readonly property color textMutedOnDark: "#9090c0"

    // ── Acento ────────────────────────────────────────────
    readonly property color accent:        "#7c4dff"
    readonly property color accentLight:   dark ? "#bb86fc" : "#6200ee"

    // ── Estados ───────────────────────────────────────────
    readonly property color success:       dark ? "#69f0ae" : "#1b7a3e"
    readonly property color successBg:     dark ? "#0d2a1a" : "#c8f5dc"
    readonly property color successBadge:  dark ? "#1b5e20" : "#2e7d32"
    readonly property color error:         "#ef5350"
    readonly property color errorBg:       dark ? "#b00020" : "#c62828"
    readonly property color warning:       dark ? "#ffab40" : "#e65100"
    readonly property color warningBg:     dark ? "#3d1a00" : "#fff3e0"

    // ── Tarjetas ──────────────────────────────────────────
    readonly property color cardBg:        dark ? "#1e1e3a" : "#ffffff"
    readonly property color cardBorder:    dark ? "#2a2a4a" : "#d0d4ee"
    readonly property color cardHover:     dark ? "#2a2a4a" : "#f0f2ff"

    // ── Overlay ───────────────────────────────────────────
    readonly property color overlay:       "#80000000"
}
