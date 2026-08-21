import Foundation

/// Single source of truth for the running app's on-disk identity.
///
/// Fleet and cmux are separate apps that run side by side, so they must not share
/// config, auth tokens, or session snapshots: two apps restoring from one snapshot
/// file overwrite each other's workspaces. `UserDefaults` is already keyed by bundle
/// id, but these filesystem paths are not — so the directory name derives from that
/// same bundle id here, once, instead of each of the ~30 call sites hardcoding one.
/// Derived rather than compiled in so a Debug build keeps reading the `cmux`
/// directories it has always used while a Fleet build starts clean.
public enum FleetAppIdentity {
    public static let fleetBundlePrefix = "com.tankxu.fleet"
    public static let fleetDirectoryName = "fleet"
    public static let legacyDirectoryName = "cmux"

    /// Directory name for config, Application Support, and other on-disk state.
    public static let stateDirectoryName: String = directoryName(
        forBundleIdentifier: Bundle.main.bundleIdentifier
    )

    /// `~/.config/<name>`, the user-facing config directory, without the home prefix.
    public static var configDirectoryRelativePath: String {
        ".config/" + stateDirectoryName
    }

    /// Path shown in settings UI and CLI help.
    public static var configDirectoryDisplayPath: String {
        "~/" + configDirectoryRelativePath
    }

    /// Config file base name, so a Fleet install does not keep a `cmux.json`
    /// inside its own directory.
    public static var configFileName: String { stateDirectoryName + ".json" }

    /// `~/.config/<name>/<name>.json`, for settings UI and CLI help text.
    public static var configFileDisplayPath: String {
        configDirectoryDisplayPath + "/" + configFileName
    }

    /// Relative path from home to the config file.
    public static var configFileRelativePath: String {
        configDirectoryRelativePath + "/" + configFileName
    }

    /// Name of the bundled CLI and of the symlink the app installs into PATH.
    /// Keyed to the identity so installing Fleet's CLI cannot overwrite the cmux
    /// binary an existing cmux install put there.
    public static var cliCommandName: String { stateDirectoryName }

    /// Pure mapping, exposed so the identity split is testable without launching an app.
    public static func directoryName(forBundleIdentifier identifier: String?) -> String {
        guard let identifier, identifier.hasPrefix(fleetBundlePrefix) else {
            return legacyDirectoryName
        }
        return fleetDirectoryName
    }
}
