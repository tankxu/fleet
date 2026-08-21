import AppKit
import CmuxFoundation
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Bonsplit accents the selected-tab indicator and unread dots with the system
/// accent color unless the host injects one. macOS lets a user's accent
/// preference override the app's accent asset, so without this injection the
/// pane tab bar renders system blue over otherwise green cmux chrome.
@Suite("Bonsplit chrome accent")
struct BonsplitChromeAccentTests {
    private func components(_ hex: String) throws -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let color = try #require(NSColor(bonsplitHexForTests: hex)?.usingColorSpace(.sRGB))
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }

    @Test("Pane chrome carries the cmux theme accent")
    func paneChromeCarriesThemeAccent() throws {
        let colors = Workspace.resolvedChromeColors(from: .black)
        let accentHex = try #require(colors.accentHex)

        #expect(accentHex == CmuxThemeAccent.nsColor.hexString(includeAlpha: true))
    }

    @Test("The injected accent is the green theme color, not a blue system accent")
    func injectedAccentIsGreen() throws {
        let accentHex = try #require(Workspace.resolvedChromeColors(from: .black).accentHex)
        let rgb = try components(accentHex)

        #expect(rgb.green > rgb.red)
        #expect(rgb.green > rgb.blue)
    }

    @Test("Chrome sharing the window backdrop still carries the accent")
    func windowBackdropChromeCarriesAccent() throws {
        let colors = Workspace.resolvedChromeColors(from: .black, sharesWindowBackdrop: true)

        #expect(colors.accentHex == CmuxThemeAccent.nsColor.hexString(includeAlpha: true))
    }

    @Test("Opacity-resolved chrome carries the accent in both backdrop modes")
    func opacityResolvedChromeCarriesAccent() {
        let expected = CmuxThemeAccent.nsColor.hexString(includeAlpha: true)

        for sharesWindowBackdrop in [true, false] {
            let colors = Workspace.bonsplitChromeColors(
                backgroundColor: .black,
                backgroundOpacity: 0.9,
                sharesWindowBackdrop: sharesWindowBackdrop
            )
            #expect(colors.accentHex == expected, "sharesWindowBackdrop=\(sharesWindowBackdrop)")
        }
    }

    @Test("A theme accent change is visible to chrome equality")
    func accentChangeBreaksChromeEquality() {
        let themed = Workspace.resolvedChromeColors(from: .black)
        var systemAccented = themed
        systemAccented.accentHex = "#0091FFFF"

        #expect(themed.accentHex != systemAccented.accentHex)
    }
}

private extension NSColor {
    /// Parses `#RRGGBB` / `#RRGGBBAA`, matching Bonsplit's own hex handling.
    convenience init?(bonsplitHexForTests hex: String) {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6 || value.count == 8, let raw = UInt64(value, radix: 16) else { return nil }
        let hasAlpha = value.count == 8
        let red = CGFloat((raw >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((raw >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((raw >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(raw & 0xFF) / 255 : 1
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}
