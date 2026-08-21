import Foundation

/// Reads `ui.fleetCanvas.enabledByDefault` from the config file at launch.
///
/// A narrow standalone read rather than the full config pipeline: the board's
/// default has to be registered before the first window is built, and
/// `CmuxConfigStore` is created per window, well after that point. It reuses
/// `JSONCParser` so comments and trailing commas are handled exactly as the
/// main config loader handles them, instead of a second JSONC implementation
/// that could disagree with the first.
enum FleetCanvasLaunchDefault {
    /// Returns the configured value, or nil when the file is missing, malformed,
    /// or simply does not mention the setting. A broken config must not decide
    /// whether the board appears, so every failure is nil and the built-in
    /// default applies.
    static func configuredValue(fileURL: URL) -> Bool? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return configuredValue(configData: data)
    }

    /// Exposed for tests: parsing is where this can silently go wrong.
    static func configuredValue(configData: Data) -> Bool? {
        guard let json = try? JSONCParser.preprocess(data: configData),
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let ui = root["ui"] as? [String: Any],
              let canvas = ui["fleetCanvas"] as? [String: Any]
        else { return nil }
        return canvas["enabledByDefault"] as? Bool
    }
}
