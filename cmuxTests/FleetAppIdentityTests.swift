import CmuxFoundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#else
@testable import cmux
#endif

@Suite("Fleet app identity")
struct FleetAppIdentityTests {
    @Test("Fleet bundle ids get their own state directory")
    func fleetBundleUsesFleetDirectory() {
        #expect(FleetAppIdentity.directoryName(forBundleIdentifier: "com.tankxu.fleet") == "fleet")
        #expect(
            FleetAppIdentity.directoryName(forBundleIdentifier: "com.tankxu.fleet.docktileplugin")
                == "fleet"
        )
    }

    @Test("cmux bundle ids keep the existing directory")
    func cmuxBundlesKeepLegacyDirectory() {
        // A Debug or nightly build must keep reading the ~/.config/cmux state it
        // already has; only a Fleet-identity build starts in its own directory.
        for identifier in [
            "com.cmuxterm.app",
            "com.cmuxterm.app.debug",
            "com.cmuxterm.app.debug.tag.fleet-canvas",
            "com.cmuxterm.app.nightly",
        ] {
            #expect(FleetAppIdentity.directoryName(forBundleIdentifier: identifier) == "cmux")
        }
        #expect(FleetAppIdentity.directoryName(forBundleIdentifier: nil) == "cmux")
    }

    @Test("Config paths derive from the state directory")
    func configPathsFollowIdentity() {
        // The file name follows the identity too, so a Fleet install does not end up
        // with a cmux.json sitting inside ~/.config/fleet.
        let directory = FleetAppIdentity.stateDirectoryName
        #expect(FleetAppIdentity.configDirectoryRelativePath == ".config/\(directory)")
        #expect(FleetAppIdentity.configFileName == "\(directory).json")
        #expect(FleetAppIdentity.configFileRelativePath == ".config/\(directory)/\(directory).json")
        #expect(FleetAppIdentity.configFileDisplayPath == "~/.config/\(directory)/\(directory).json")
    }

    @Test("Fleet registers its own auth callback scheme")
    func fleetUsesOwnCallbackScheme() {
        // Two installed apps claiming cmux:// means the sign-in callback can land in
        // the wrong one, which reads to the user as a broken login.
        let fleet = AuthEnvironment.callbackScheme(
            environment: [:],
            bundleIdentifier: "com.tankxu.fleet",
            isDebugBuild: false
        )
        #expect(fleet == "fleet")

        let stable = AuthEnvironment.callbackScheme(
            environment: [:],
            bundleIdentifier: "com.cmuxterm.app",
            isDebugBuild: false
        )
        #expect(stable == "cmux")

        let nightly = AuthEnvironment.callbackScheme(
            environment: [:],
            bundleIdentifier: "com.cmuxterm.app.nightly",
            isDebugBuild: false
        )
        #expect(nightly == "cmux-nightly")
    }

    @Test("An explicit scheme override still wins for Fleet")
    func overrideWinsOverFleetDefault() {
        // The bridge until "fleet" is live in the web allowlist.
        let overridden = AuthEnvironment.callbackScheme(
            environment: ["CMUX_AUTH_CALLBACK_SCHEME": "cmux"],
            bundleIdentifier: "com.tankxu.fleet",
            isDebugBuild: false
        )
        #expect(overridden == "cmux")
    }
}
