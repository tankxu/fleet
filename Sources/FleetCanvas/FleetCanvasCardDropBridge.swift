import AppKit
import Foundation

/// Carries workspace drops that land on a card's terminal area from AppKit to the
/// fleet board.
///
/// The board's own SwiftUI drop target cannot see these. A card's body is a
/// terminal portal — an AppKit view that sits above the SwiftUI hierarchy as a
/// sibling — so AppKit resolves the drop inside the portal and never consults
/// SwiftUI. cmux's portal pass-through does not help either: it keys off
/// `NSApp.currentEvent`, which during a real dragging session is not a mouse-drag
/// event, and it exists to hand drops to the pane drop target rather than to
/// SwiftUI.
///
/// So the pane drop target reports what it sees and the board decides. Only the
/// hovered workspace and a normalized point are sent: the board already knows
/// every card's geometry, and window-coordinate math across two flipped
/// coordinate spaces is a bug factory.
enum FleetCanvasCardDropBridge {
    static let notificationName = Notification.Name("cmux.fleetCanvas.cardDrop")

    enum Phase: String {
        case hover
        case exit
        case perform
    }

    private enum Key {
        static let phase = "phase"
        static let workspaceId = "workspaceId"
        static let edge = "edge"
    }

    /// Whether the board is up and should receive these reports at all.
    ///
    /// Read from defaults rather than passed in: the reporter is deep in the
    /// terminal view hierarchy, and in normal presentation a workspace drop onto a
    /// terminal has no meaning and must keep having none.
    static var isBoardPresented: Bool {
        UserDefaults.standard.bool(forKey: FleetCanvasSettings.enabledKey)
    }

    static func post(phase: Phase, workspaceId: UUID, edge: FleetCanvasLayoutEdge?) {
        var userInfo: [String: Any] = [
            Key.phase: phase.rawValue,
            Key.workspaceId: workspaceId,
        ]
        if let edge {
            userInfo[Key.edge] = edge.rawValue
        }
        NotificationCenter.default.post(
            name: notificationName,
            object: nil,
            userInfo: userInfo
        )
    }

    /// Decoded report, or `nil` when the notification is malformed.
    static func decode(_ notification: Notification) -> (phase: Phase, workspaceId: UUID, edge: FleetCanvasLayoutEdge?)? {
        guard let info = notification.userInfo,
              let rawPhase = info[Key.phase] as? String,
              let phase = Phase(rawValue: rawPhase),
              let workspaceId = info[Key.workspaceId] as? UUID else {
            return nil
        }
        let edge = (info[Key.edge] as? String).flatMap(FleetCanvasLayoutEdge.init(rawValue:))
        return (phase, workspaceId, edge)
    }
}
