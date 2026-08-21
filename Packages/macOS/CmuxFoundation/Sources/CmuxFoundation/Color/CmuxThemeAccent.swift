public import AppKit
public import SwiftUI

/// The cmux theme color.
///
/// Every accented surface resolves here — sidebar selection, pane and tab
/// chrome, drop indicators, notification rings, fleet-canvas card focus — so
/// the app has exactly one place to shift hue.
///
/// Deliberately *not* `NSColor.controlAccentColor`: that follows the user's
/// macOS accent preference and overrides the app's own accent asset whenever
/// the preference is a specific color rather than Multicolor, which would leave
/// cmux chrome tinted system blue no matter what the app ships.
public enum CmuxThemeAccent {
    /// Theme color for a resolved appearance.
    public static func nsColor(for colorScheme: ColorScheme) -> NSColor {
        switch colorScheme {
        case .dark:
            return NSColor(
                srgbRed: 26.0 / 255.0,
                green: 188.0 / 255.0,
                blue: 138.0 / 255.0,
                alpha: 1.0
            )
        default:
            return NSColor(
                srgbRed: 13.0 / 255.0,
                green: 148.0 / 255.0,
                blue: 108.0 / 255.0,
                alpha: 1.0
            )
        }
    }

    /// Theme color for an AppKit appearance.
    public static func nsColor(for appAppearance: NSAppearance?) -> NSColor {
        let bestMatch = appAppearance?.bestMatch(from: [.darkAqua, .aqua])
        return nsColor(for: bestMatch == .darkAqua ? .dark : .light)
    }

    /// Appearance-resolving theme color.
    public static var nsColor: NSColor {
        NSColor(name: nil) { appearance in
            nsColor(for: appearance)
        }
    }

    /// Appearance-resolving theme color for SwiftUI.
    public static var color: Color {
        Color(nsColor: nsColor)
    }
}
