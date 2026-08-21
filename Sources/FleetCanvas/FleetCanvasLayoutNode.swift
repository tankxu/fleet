import CoreGraphics
import Foundation

/// A fleet board's layout: containers of workspaces and nested containers.
///
/// A container lays any number of members along one axis, which is what keeps
/// three cards the same width and makes a fourth card a quarter rather than a
/// half. A binary tree cannot do either: every edit there is a split, so cards
/// halve as they are added and reordering does not exist — moving a card can only
/// pair it with something.
///
/// Grouping is then just nesting: replace one member with a container holding
/// that member plus the newcomer, on the perpendicular axis. Containers nest
/// without limit.
indirect enum FleetCanvasLayoutNode: Codable, Equatable {
    /// A leaf: one workspace card.
    case workspace(UUID)

    /// Members laid out along `axis`, sized by `weights`.
    case container(axis: FleetCanvasSplitAxis, members: [FleetCanvasLayoutNode], weights: [CGFloat])

    /// Smallest share of a container a member may be squeezed to.
    static let minimumWeightFraction: CGFloat = 0.08

    /// Workspaces in layout order.
    var workspaceIds: [UUID] {
        switch self {
        case let .workspace(id):
            return [id]
        case let .container(_, members, _):
            return members.flatMap(\.workspaceIds)
        }
    }

    var isLeaf: Bool {
        if case .workspace = self { return true }
        return false
    }

    /// Number of workspaces under this node.
    var count: Int { workspaceIds.count }

    /// Axis of this node when it is a container.
    var containerAxis: FleetCanvasSplitAxis? {
        if case let .container(axis, _, _) = self { return axis }
        return nil
    }

    /// Direct members of this node when it is a container.
    var memberCount: Int {
        if case let .container(_, members, _) = self { return members.count }
        return 0
    }

    /// Weight fractions for a container's members, summing to 1.
    ///
    /// Stored weights can be the wrong length or contain junk — a container gains
    /// and loses members over its lifetime — so they are fitted rather than
    /// trusted.
    static func fractions(weights: [CGFloat], memberCount: Int) -> [CGFloat] {
        guard memberCount > 0 else { return [] }
        let sanitized = weights.filter { $0.isFinite && $0 > 0 }
        guard !sanitized.isEmpty else {
            return Array(repeating: 1 / CGFloat(memberCount), count: memberCount)
        }
        var fitted = Array(sanitized.prefix(memberCount))
        if fitted.count < memberCount {
            let average = fitted.reduce(0, +) / CGFloat(fitted.count)
            fitted.append(contentsOf: Array(repeating: average, count: memberCount - fitted.count))
        }
        let total = fitted.reduce(0, +)
        guard total > 0 else {
            return Array(repeating: 1 / CGFloat(memberCount), count: memberCount)
        }
        return fitted.map { $0 / total }
    }
}
