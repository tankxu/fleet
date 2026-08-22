import Foundation

/// Reads individual settings from the config file at launch, before the full
/// config pipeline exists.
///
/// Some defaults have to be known before the first window is built — the board's
/// visibility resolves during view construction, and session restore is decided
/// in `applicationDidFinishLaunching` — while `CmuxConfigStore` is created per
/// window, well after both. This reads just the value asked for, reusing
/// `JSONCParser` so comments and trailing commas behave exactly as they do in the
/// main loader rather than through a second implementation that could disagree.
///
/// Every failure yields nil so the built-in default applies: a malformed config
/// must not decide whether the app opens a window at all.
enum FleetLaunchConfig {
    /// Boolean at a key path, e.g. `["ui", "fleetCanvas", "enabledByDefault"]`.
    static func bool(atPath path: [String], fileURL: URL) -> Bool? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return bool(atPath: path, configData: data)
    }

    /// Exposed for tests: parsing is where this can silently go wrong.
    static func bool(atPath path: [String], configData: Data) -> Bool? {
        guard let json = try? JSONCParser.preprocess(data: configData),
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any]
        else { return nil }

        var node: Any = root
        for key in path {
            guard let dictionary = node as? [String: Any],
                  let next = dictionary[key]
            else { return nil }
            node = next
        }
        return node as? Bool
    }
}
