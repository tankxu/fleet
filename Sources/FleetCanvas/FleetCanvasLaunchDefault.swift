import Foundation

/// Reads `ui.fleetCanvas.enabledByDefault` from the config file at launch.
enum FleetCanvasLaunchDefault {
    static let configPath = ["ui", "fleetCanvas", "enabledByDefault"]

    static func configuredValue(fileURL: URL) -> Bool? {
        FleetLaunchConfig.bool(atPath: configPath, fileURL: fileURL)
    }

    static func configuredValue(configData: Data) -> Bool? {
        FleetLaunchConfig.bool(atPath: configPath, configData: configData)
    }
}
