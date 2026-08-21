import CoreGraphics
import Foundation

/// Persists the board's layout tree.
///
/// The tree is the layout, and it survives workspaces opening and closing by
/// being reconciled against the live list on every pass.
enum FleetCanvasLayoutTreeStore {
    static let defaultsKey = "fleetCanvasLayoutTree"

    /// The stored tree, or `nil` when nothing is stored or the stored value is
    /// unreadable. A corrupt preference must fall back to a generated layout
    /// rather than break the board.
    static func tree(in raw: String) -> FleetCanvasLayoutNode? {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FleetCanvasLayoutNode.self, from: data)
    }

    static func encode(_ tree: FleetCanvasLayoutNode?) -> String {
        guard let tree, let data = try? JSONEncoder().encode(tree) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

}
