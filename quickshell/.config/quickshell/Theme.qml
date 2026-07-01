pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ===== PALETTE — Serial Experiments Lain =====
    // Based on actual reference: Lain's NAVI interface, her room lighting,
    // the power lines, and the Wired's phosphor-green terminal aesthetic.

    // Near-black — neutral dark, very slight warm tint like a CRT in a dark room
    property color bg:    Qt.hsla(0.08, 0.08, 0.06, 1.0)
    // Foreground — warm pale phosphor white, not cold/blue
    property color fg:    Qt.hsla(0.22, 0.12, 0.90, 1.0)
    // Muted — dim phosphor, clearly secondary but readable
    property color muted: Qt.hsla(0.28, 0.18, 0.55, 1.0)

    // ===== ACCENTS =====
    // Primary: CRT P1 phosphor green — H≈127°, the actual color of Lain's terminal
    property color accent:    Qt.hsla(0.353, 0.90, 0.62, 1.0)
    // Secondary: amber — the warm analog glow, Lain's room lighting, old monitors
    property color accentAlt: Qt.hsla(0.105, 0.95, 0.60, 1.0)
    // Warning: deeper orange (distinct from amber accent)
    property color warning:   Qt.hsla(0.075, 0.95, 0.58, 1.0)
    // Critical: red, used sparingly
    property color critical:  Qt.hsla(0.0,   0.88, 0.60, 1.0)

    // ===== BAR / CHIP BACKGROUNDS =====
    property real barOpacity: 0.97
    property color barBg: Qt.hsla(bg.hslHue, bg.hslSaturation, bg.hslLightness, barOpacity)

    // Left chip — slightly warm dark, like a dim lit surface
    property color chipLeftBg:  Qt.hsla(0.10, 0.10, 0.12, 0.98)
    // Right chip — very faint phosphor-green glow, like a terminal panel
    property color chipRightBg: Qt.hsla(accent.hslHue, 0.30, 0.10, 0.98)

    property color chipBorder: Qt.rgba(accent.r, accent.g, accent.b, 0.25)

    // ===== LAYOUT =====
    property int barHeight: 34

    // ===== RADII =====
    property int radiusSm: 6
    property int radius:   10
    property int radiusLg: 14

    // ===== SPACING =====
    property int paddingSm:  6
    property int padding:    10
    property int paddingLg:  16
    property int chipPadding: 10
    property int chipGap:     8

    // ===== TEXT =====
    property int fontXs: 12
    property int fontSm: 14
    property int fontMd: 16
    property int fontLg: 20
    property int fontXl: 24

    property int fontWeight: Font.DemiBold

    property string fontMono: "Terminess Nerd Font"
    property string fontUi:   "Terminess Nerd Font"

    // ===== STATUS COLORS =====
    // "ok" stays phosphor green — healthy terminal output
    property color ok:     accent
    // "busy/active" is amber — warm analog activity
    property color busy:   accentAlt
    property color idle:   muted
    property color alert:  warning
    property color danger: critical
}
