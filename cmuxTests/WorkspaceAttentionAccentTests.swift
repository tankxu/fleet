import AppKit
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The unread ring and focus flash must stay visually distinct from the theme
/// accent. Folding them into the accent (as an earlier pass did) makes an
/// attention signal indistinguishable from ordinary green chrome.
@Suite("Workspace attention accent")
struct WorkspaceAttentionAccentTests {
    private func srgb(_ color: NSColor) throws -> NSColor {
        try #require(color.usingColorSpace(.sRGB))
    }

    @Test("The built-in attention color is a bright yellow")
    func attentionColorIsBrightYellow() throws {
        let color = try srgb(WorkspaceAttentionFlashAccent.attentionYellow.strokeColor)

        #expect(color.redComponent > 0.9)
        #expect(color.greenComponent > 0.7)
        #expect(color.blueComponent < 0.3)
    }

    @Test("Rings and flashes both use the attention color")
    func ringAndFlashShareAttentionColor() {
        #expect(WorkspaceAttentionCoordinator.notificationRingStyle.accent == .attentionYellow)
        #expect(WorkspaceAttentionCoordinator.flashRingStyle.accent == .attentionYellow)
    }

    @Test("The attention color is not the theme accent")
    func attentionColorDiffersFromThemeAccent() throws {
        let attention = try srgb(WorkspaceAttentionFlashAccent.attentionYellow.strokeColor)
        let theme = try srgb(cmuxAccentNSColor())

        #expect(attention.redComponent != theme.redComponent)
        #expect(attention.blueComponent != theme.blueComponent)
    }

    @Test("An unconfigured attention color falls back to the built-in yellow")
    func unconfiguredColorFallsBackToYellow() throws {
        let resolved = try srgb(WorkspaceAttentionColor(configuredHex: nil).nsColor)
        let builtIn = try srgb(WorkspaceAttentionFlashAccent.attentionYellow.strokeColor)

        #expect(resolved.redComponent == builtIn.redComponent)
        #expect(resolved.greenComponent == builtIn.greenComponent)
        #expect(resolved.blueComponent == builtIn.blueComponent)
    }

    @Test("A configured hex still overrides the built-in color")
    func configuredHexOverrides() throws {
        let resolved = try srgb(WorkspaceAttentionColor(configuredHex: "#FF0000").nsColor)

        #expect(resolved.redComponent > 0.9)
        #expect(resolved.greenComponent < 0.1)
    }
}
