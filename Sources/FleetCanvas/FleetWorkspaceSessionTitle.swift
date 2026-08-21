import Foundation

/// Cleans an agent session title for use as a card label.
///
/// Coding agents prefix their terminal title with an animated spinner glyph
/// (`✻ working on…`, `⠹ building`). On a pane's own tab that animation reads as
/// liveness, but a board of cards showing the same glyph cycling in every title
/// is just flicker, and the glyph carries no information the card's status row
/// does not already show.
enum FleetWorkspaceSessionTitle {
    /// Spinner and ornament glyphs agents animate. Deliberately excludes
    /// characters that can start a real title — `/` (slash commands), `#`, `~`,
    /// `.` — so stripping never eats content.
    private static let ornaments: Set<Character> = [
        "✳", "✴", "✵", "✶", "✷", "✸", "✹", "✺", "✻", "✽", "✾", "❋",
        "✦", "✧", "∗", "✱", "✲", "*", "◐", "◓", "◑", "◒", "●", "○",
        "•", "·", "▪", "▫", "◆", "◇", "★", "☆",
    ]

    /// Braille-pattern block, used wholesale by common CLI spinners.
    private static let brailleRange: ClosedRange<UInt32> = 0x2800 ... 0x28FF

    /// `title` with animated ornaments trimmed from both ends.
    ///
    /// Returns the trimmed original when a title is nothing but ornaments, so a
    /// card never ends up with an empty label.
    static func sanitized(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var slice = Substring(trimmed)
        while let first = slice.first, isOrnament(first) || first.isWhitespace {
            slice = slice.dropFirst()
        }
        while let last = slice.last, isOrnament(last) || last.isWhitespace {
            slice = slice.dropLast()
        }
        let cleaned = String(slice)
        return cleaned.isEmpty ? trimmed : cleaned
    }

    private static func isOrnament(_ character: Character) -> Bool {
        if ornaments.contains(character) { return true }
        guard let scalar = character.unicodeScalars.first,
              character.unicodeScalars.count == 1 else { return false }
        return brailleRange.contains(scalar.value)
    }
}
