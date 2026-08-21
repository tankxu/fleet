import CoreGraphics
import Foundation

/// What a drop at some point on the board would do.
enum FleetCanvasDropIntent: Equatable {
    /// Insert as a sibling at `index` of the container at `path`.
    case sibling(path: FleetCanvasLayoutPath, index: Int)

    /// Group with the card `workspaceId`, on `edge` of it.
    case group(workspaceId: UUID, edge: FleetCanvasLayoutEdge)
}
