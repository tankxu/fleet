import CoreGraphics
import Foundation

/// Where one workspace card sits on the board.
struct FleetCanvasLayoutFrame: Equatable, Identifiable {
    let workspaceId: UUID
    let rect: CGRect

    var id: UUID { workspaceId }
}

/// A divider between two adjacent members of one container.
struct FleetCanvasLayoutDivider: Equatable, Identifiable {
    /// Address of the container the divider belongs to.
    let path: FleetCanvasLayoutPath

    /// Index of the member on the leading side of the divider.
    let leadingIndex: Int

    let axis: FleetCanvasSplitAxis

    /// The gap the divider occupies.
    let rect: CGRect

    /// The container's extent along its axis, minus gaps, so a drag in points can
    /// be converted into weight fractions.
    let usableLength: CGFloat

    /// The container's current weight fractions.
    let fractions: [CGFloat]

    var id: String { "\(path.indices.map(String.init).joined(separator: "."))#\(leadingIndex)" }
}

/// Resolved geometry for a whole board.
struct FleetCanvasLayoutSolution: Equatable {
    let frames: [FleetCanvasLayoutFrame]
    let dividers: [FleetCanvasLayoutDivider]

    static let empty = FleetCanvasLayoutSolution(frames: [], dividers: [])
}

extension FleetCanvasLayoutNode {
    /// Lays the tree out inside `rect`, reserving `spacing` between members.
    ///
    /// Coordinates follow SwiftUI's: y grows downward, so a vertical container's
    /// first member is the upper one.
    func solve(in rect: CGRect, spacing: CGFloat) -> FleetCanvasLayoutSolution {
        var frames: [FleetCanvasLayoutFrame] = []
        var dividers: [FleetCanvasLayoutDivider] = []
        accumulate(in: rect, spacing: spacing, path: .root, frames: &frames, dividers: &dividers)
        return FleetCanvasLayoutSolution(frames: frames, dividers: dividers)
    }

    private func accumulate(
        in rect: CGRect,
        spacing: CGFloat,
        path: FleetCanvasLayoutPath,
        frames: inout [FleetCanvasLayoutFrame],
        dividers: inout [FleetCanvasLayoutDivider]
    ) {
        switch self {
        case let .workspace(id):
            frames.append(FleetCanvasLayoutFrame(workspaceId: id, rect: rect))
        case let .container(axis, members, weights):
            guard !members.isEmpty else { return }
            let fractions = Self.fractions(weights: weights, memberCount: members.count)
            let gaps = spacing * CGFloat(members.count - 1)
            let usable = max(1, (axis == .horizontal ? rect.width : rect.height) - gaps)
            var offset = axis == .horizontal ? rect.minX : rect.minY

            for (index, member) in members.enumerated() {
                let length = max(1, usable * fractions[index])
                let memberRect = axis == .horizontal
                    ? CGRect(x: offset, y: rect.minY, width: length, height: rect.height)
                    : CGRect(x: rect.minX, y: offset, width: rect.width, height: length)
                member.accumulate(
                    in: memberRect,
                    spacing: spacing,
                    path: path.appending(index),
                    frames: &frames,
                    dividers: &dividers
                )
                offset += length
                if index < members.count - 1 {
                    dividers.append(FleetCanvasLayoutDivider(
                        path: path,
                        leadingIndex: index,
                        axis: axis,
                        rect: axis == .horizontal
                            ? CGRect(x: offset, y: rect.minY, width: spacing, height: rect.height)
                            : CGRect(x: rect.minX, y: offset, width: rect.width, height: spacing),
                        usableLength: usable,
                        fractions: fractions
                    ))
                    offset += spacing
                }
            }
        }
    }
}
