import CoreGraphics
import Foundation

/// Resolves a card drag into layout intent.
///
/// With a tree layout there is no "insert at index" any more: a drop says which
/// side of which card the dragged workspace should occupy, and the tree grows a
/// group there.
enum FleetCanvasDropTarget {
    /// The edge of a card of `size` that a drop at `location` targets.
    ///
    /// The card is divided by its diagonals, so the nearest edge wins. That makes
    /// the four zones equal and predictable, unlike bands that leave an ambiguous
    /// middle.
    static func edge(location: CGPoint, size: CGSize) -> FleetCanvasLayoutEdge {
        guard size.width > 0, size.height > 0 else { return .trailing }
        let horizontal = location.x / size.width - 0.5
        let vertical = location.y / size.height - 0.5
        if abs(horizontal) >= abs(vertical) {
            return horizontal < 0 ? .leading : .trailing
        }
        return vertical < 0 ? .top : .bottom
    }

    /// Whether the drop would change the layout at all.
    ///
    /// Compares the resulting tree rather than reasoning about positions: dropping
    /// a card back onto the side it already occupies rebuilds the same tree, and
    /// that must not be published as a layout change.
    static func changesLayout(
        draggedWorkspaceId: UUID,
        targetWorkspaceId: UUID,
        edge: FleetCanvasLayoutEdge,
        tree: FleetCanvasLayoutNode
    ) -> Bool {
        guard draggedWorkspaceId != targetWorkspaceId else { return false }
        guard tree.workspaceIds.contains(targetWorkspaceId),
              tree.workspaceIds.contains(draggedWorkspaceId) else { return false }
        return tree.moving(draggedWorkspaceId, nextTo: targetWorkspaceId, edge: edge) != tree
    }
}
