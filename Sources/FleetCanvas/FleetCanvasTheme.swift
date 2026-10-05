import AppKit
import SwiftUI

/// Chrome tokens shared by every fleet-canvas surface.
///
/// The board has to read as one tinted environment, so selection, status
/// glyphs, and glass tints resolve here instead of each view hard-coding its
/// own green. The accent itself comes from `cmuxAccentColor()`, so the board
/// can never drift from the app-wide theme color.
enum FleetCanvasTheme {
    /// App theme color, used for selection and running work.
    static var accent: Color { cmuxAccentColor() }

    /// Border of the workspace card that owns keyboard input.
    static var selectedCardBorder: Color { accent.opacity(0.92) }

    /// Border of every other workspace card.
    static func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.10) : Color.white.opacity(0.12)
    }

    /// Hairline between a card's header and its content.
    static func cardHeaderDivider(_ scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.07) : Color.white.opacity(0.08)
    }

    /// Fill that lifts a card's header off its terminal background.
    static func cardHeaderFill(_ scheme: ColorScheme, isSelected: Bool) -> Color {
        scheme == .light
            ? Color.black.opacity(isSelected ? 0.05 : 0.03)
            : Color.white.opacity(isSelected ? 0.10 : 0.06)
    }

    /// Hover fill behind an editable card title.
    static func cardTitleHoverFill(_ scheme: ColorScheme) -> Color {
        scheme == .light ? Color.black.opacity(0.06) : Color.white.opacity(0.10)
    }

    /// Drop shadow under a card. A light board needs far less: the dark-board
    /// shadow reads as a smudge on pale glass.
    static func cardShadow(_ scheme: ColorScheme) -> Color {
        Color.black.opacity(scheme == .light ? 0.12 : 0.34)
    }

    /// Insertion marker shown while a card is dragged to a new position.
    static var reorderIndicator: Color { accent }

    /// Agents that are actively producing output.
    static var runningAgent: Color { accent }

    /// Agents blocked on the user. Amber stays amber: a board tinted green end
    /// to end would erase the one status that has to interrupt.
    static let needsInputAgent = Color(red: 1.0, green: 0.72, blue: 0.30)

    /// Agents that exited cleanly — the same hue family as the accent, muted so
    /// finished work recedes behind running work.
    static let completedAgent = Color(red: 0.44, green: 0.80, blue: 0.60)

    /// Tint pushed into the canvas glass.
    ///
    /// Opaque enough to own its own color. A behind-window material samples a
    /// wide area of the desktop rather than refracting what is locally behind it,
    /// so a thin tint lets a saturated wallpaper bleed across the whole window
    /// even when the colored region is nowhere near it. The glass still supplies
    /// the highlights and edge treatment; the tint is what keeps the surface
    /// reading as cmux's own chrome instead of as whatever is on the desktop.
    ///
    /// Follows the window's chrome scheme, which tracks the terminal theme: a
    /// light theme puts light cards on the board, and a dark board around them
    /// would read as a hole cut in the window.
    ///
    /// The light tint is much thinner than the dark one. Light glass already
    /// whitens what it refracts, so at the dark board's opacity it reads as a
    /// flat panel; a wallpaper bleeding through pale glass also reads as
    /// translucency rather than as a color cast.
    static func canvasGlassTint(_ scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.925, green: 0.945, blue: 0.935).opacity(0.40)
            : Color(red: 0.043, green: 0.063, blue: 0.058).opacity(0.86)
    }

    /// Tint pushed into the right sidebar's glass. Set slightly apart from the
    /// canvas so the sidebar still separates from the board behind it.
    static func sidebarGlassTint(_ scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.955, green: 0.968, blue: 0.962).opacity(0.82)
            : Color(red: 0.055, green: 0.075, blue: 0.07).opacity(0.82)
    }

    /// Opacity applied to a card's terminal background fill. Cards must stay
    /// legible, so they sit far closer to opaque than the canvas behind them —
    /// that contrast is what separates card from board.
    static let cardBackgroundOpacity: CGFloat = 0.82

    /// Corner radius shared by cards and their glass.
    static let cardCornerRadius: CGFloat = 12
}
