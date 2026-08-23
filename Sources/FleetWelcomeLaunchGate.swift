import Foundation

/// Lets the welcome banner print once per launch.
///
/// Upstream gates it on the persisted `cmuxWelcomeShown` flag, which means it
/// greets you once in the lifetime of an install and never again. Fleet shows it
/// on every launch instead, so the gate has to be process-scoped: a persisted flag
/// cannot express "once per launch" at all.
///
/// The persisted flag is still written, because other code reads it as an
/// "already onboarded" signal.
@MainActor
enum FleetWelcomeLaunchGate {
    private static var shown = false

    /// Whether this launch still owes a welcome.
    static var shouldShow: Bool { !shown }

    /// Claims the launch's single welcome. Idempotent.
    static func markShown() { shown = true }

    /// Testing seam: process state would otherwise leak between tests.
    static func resetForTesting() { shown = false }
}
