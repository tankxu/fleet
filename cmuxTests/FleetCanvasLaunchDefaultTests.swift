import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#else
@testable import cmux
#endif

@Suite("Fleet canvas launch default")
struct FleetCanvasLaunchDefaultTests {
    private func defaults(_ name: String) -> UserDefaults {
        let suite = UserDefaults(suiteName: "fleet.canvas.launch.\(name)")!
        suite.removePersistentDomain(forName: "fleet.canvas.launch.\(name)")
        return suite
    }

    @Test("The board is on when nothing says otherwise")
    func onByDefault() {
        #expect(FleetCanvasSettings.resolvedDefault(configured: nil))
        // An untouched store must report the same thing the launch value resolves
        // to, or the titlebar and the drop logic can disagree about the board.
        #expect(FleetCanvasSettings.isEnabled(defaults(#function)))
    }

    @Test("Config can turn it off at launch")
    func configTurnsItOff() {
        #expect(FleetCanvasSettings.resolvedDefault(configured: false) == false)
        #expect(FleetCanvasSettings.resolvedDefault(configured: true))
    }

    @Test("A value the user set wins over the config default")
    func userChoiceWinsOverConfig() {
        // Registration never overwrites a value the user actually set, so a board
        // the user turned off does not come back on at every launch.
        let store = defaults(#function)
        store.set(false, forKey: FleetCanvasSettings.enabledKey)
        FleetCanvasSettings.registerDefault(configured: true, defaults: store)
        #expect(FleetCanvasSettings.isEnabled(store) == false)
    }

    @Test("Key paths resolve through the shared reader")
    func sharedReaderWalksKeyPaths() {
        let jsonc = Data("""
        {
          // Both launch-time settings come through one reader.
          "ui": {
            "fleetCanvas": { "enabledByDefault": true },
            "session": { "restoreOnLaunch": false },
          },
        }
        """.utf8)
        #expect(
            FleetLaunchConfig.bool(atPath: ["ui", "session", "restoreOnLaunch"], configData: jsonc)
                == false
        )
        #expect(
            FleetLaunchConfig.bool(atPath: ["ui", "fleetCanvas", "enabledByDefault"], configData: jsonc)
                == true
        )
        // A path that runs past a leaf must not crash or invent a value.
        #expect(
            FleetLaunchConfig.bool(atPath: ["ui", "session", "restoreOnLaunch", "deeper"], configData: jsonc)
                == nil
        )
        #expect(FleetLaunchConfig.bool(atPath: ["nope"], configData: jsonc) == nil)
    }

    @Test("Reads ui.fleetCanvas.enabledByDefault, comments and all")
    func parsesJSONCConfig() {
        let jsonc = Data("""
        {
          // The board is the whole point, but it can be turned off.
          "ui": {
            "fleetCanvas": { "enabledByDefault": false },
          },
        }
        """.utf8)
        #expect(FleetCanvasLaunchDefault.configuredValue(configData: jsonc) == false)

        let on = Data(#"{"ui": {"fleetCanvas": {"enabledByDefault": true}}}"#.utf8)
        #expect(FleetCanvasLaunchDefault.configuredValue(configData: on) == true)
    }

    @Test("Unset, malformed, and unrelated configs all fall through")
    func absentOrBrokenConfigYieldsNil() {
        // A broken config must not decide whether the board appears.
        let cases: [String] = [
            "{}",
            #"{"ui": {}}"#,
            #"{"ui": {"fleetCanvas": {}}}"#,
            #"{"ui": {"fleetCanvas": {"enabledByDefault": "yes"}}}"#,
            "{ this is not json",
            "",
        ]
        for text in cases {
            #expect(FleetCanvasLaunchDefault.configuredValue(configData: Data(text.utf8)) == nil)
        }
    }

    @Test("A missing config file is not an error")
    func missingFileYieldsNil() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("fleet-does-not-exist-\(UUID().uuidString).json")
        #expect(FleetCanvasLaunchDefault.configuredValue(fileURL: missing) == nil)
    }
}
