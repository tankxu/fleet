import Foundation

/// Defaults keys owned by the fleet canvas.
enum FleetCanvasSettings {
    /// Whether the window presents the fleet board instead of one workspace.
    static let enabledKey = "fleetCanvasEnabled"

    /// The board is the reason this app exists, so it is on unless turned off.
    ///
    /// Read sites must not repeat this literal. `UserDefaults.bool(forKey:)`
    /// cannot express a `true` default at all, so the value is registered into
    /// the defaults chain at launch instead — that way `@AppStorage`, plain
    /// `bool(forKey:)`, and anything added later all resolve to one value.
    static let defaultEnabled = true

    /// Resolves the launch value from the config file, falling back to the
    /// built-in default.
    ///
    /// Kept pure and separate from registration because registration writes to
    /// the global registration domain: it cannot be undone, and it has no effect
    /// on a `UserDefaults(suiteName:)` instance — so the precedence is only
    /// testable in this form.
    static func resolvedDefault(configured: Bool?) -> Bool {
        configured ?? defaultEnabled
    }

    /// Registers the launch default so `@AppStorage` resolves to it.
    ///
    /// Registration never overrides a value the user actually set, so toggling
    /// the board in a window keeps winning over the config file.
    static func registerDefault(
        configured: Bool?,
        defaults: UserDefaults = .standard
    ) {
        defaults.register(defaults: [enabledKey: resolvedDefault(configured: configured)])
    }

    /// Current value, honoring the registered default. For call sites that only
    /// have a `UserDefaults` and no SwiftUI binding.
    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? defaultEnabled
    }
}
