/// Address of a node inside a layout tree: the member index taken at each level.
///
/// A container's identity cannot come from its contents — two containers can hold
/// the same workspaces after a move — so dividers and edits address nodes by the
/// route from the root.
struct FleetCanvasLayoutPath: Hashable, Codable {
    var indices: [Int]

    static let root = FleetCanvasLayoutPath(indices: [])

    func appending(_ index: Int) -> FleetCanvasLayoutPath {
        FleetCanvasLayoutPath(indices: indices + [index])
    }
}
