import Foundation

/// Suppresses activity-driven workspace reordering while the fleet board is up.
///
/// Normally a notification or a submitted prompt promotes its workspace to the
/// top of the list, which is useful in a vertical sidebar where the top is
/// "most recent". On the board that same promotion makes cards jump between grid
/// slots under the pointer, so a workspace you were reading moves while you read
/// it. Positions stay put; the user reorders by dragging.
enum FleetCanvasAutomaticReorderGate {
    /// Whether activity may reorder workspaces right now.
    static func allowsActivityDrivenReordering(defaults: UserDefaults = .standard) -> Bool {
        !FleetCanvasSettings.isEnabled(defaults)
    }
}
