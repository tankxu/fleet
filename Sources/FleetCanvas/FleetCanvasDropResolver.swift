import CoreGraphics
import Foundation

/// Maps a drop location on the board to layout intent.
///
/// One resolver for the whole canvas, rather than a drop target per card and per
/// divider. Per-view drop areas have to agree with SwiftUI's own hit geometry,
/// and on this board they cannot: cards and dividers are positioned with
/// `offset`, and each divider carries an AppKit view on top of it that accepts
/// hit testing so it can own the resize cursor. Resolving from coordinates keeps
/// hit behavior in one testable place instead of spread across view modifiers.
enum FleetCanvasDropResolver {
    /// How far from a divider still counts as targeting that gap.
    static let gapTolerance: CGFloat = 14

    /// Resolves `location` (in canvas coordinates) against a laid-out board.
    ///
    /// Gaps and board ends win over cards, because they are narrow and sit
    /// between much larger targets; a card is only chosen once the pointer is
    /// clear of every insertion line.
    static func intent(
        at location: CGPoint,
        solution: FleetCanvasLayoutSolution,
        tree: FleetCanvasLayoutNode,
        canvas: CGRect,
        endThickness: CGFloat
    ) -> FleetCanvasDropIntent? {
        if let end = endIntent(
            at: location,
            tree: tree,
            canvas: canvas,
            endThickness: endThickness
        ) {
            return end
        }
        if let gap = gapIntent(at: location, solution: solution) {
            return gap
        }
        return cardIntent(at: location, solution: solution)
    }

    private static func endIntent(
        at location: CGPoint,
        tree: FleetCanvasLayoutNode,
        canvas: CGRect,
        endThickness: CGFloat
    ) -> FleetCanvasDropIntent? {
        guard let axis = tree.containerAxis, tree.memberCount > 1 else { return nil }
        // An end is a band along one edge, not a half-plane. Without bounding the
        // cross axis too, a point far above a row of cards would still read as
        // "insert at the start" simply because its x sits in the leading band.
        let reachable = canvas.insetBy(dx: -endThickness, dy: -endThickness)
        guard reachable.contains(location) else { return nil }
        switch axis {
        case .horizontal:
            if location.x <= canvas.minX + endThickness {
                return .sibling(path: .root, index: 0)
            }
            if location.x >= canvas.maxX - endThickness {
                return .sibling(path: .root, index: tree.memberCount)
            }
        case .vertical:
            if location.y <= canvas.minY + endThickness {
                return .sibling(path: .root, index: 0)
            }
            if location.y >= canvas.maxY - endThickness {
                return .sibling(path: .root, index: tree.memberCount)
            }
        }
        return nil
    }

    private static func gapIntent(
        at location: CGPoint,
        solution: FleetCanvasLayoutSolution
    ) -> FleetCanvasDropIntent? {
        var best: (distance: CGFloat, intent: FleetCanvasDropIntent)?
        for divider in solution.dividers {
            let expanded = divider.rect.insetBy(
                dx: divider.axis == .horizontal ? -gapTolerance : 0,
                dy: divider.axis == .horizontal ? 0 : -gapTolerance
            )
            guard expanded.contains(location) else { continue }
            let distance = divider.axis == .horizontal
                ? abs(location.x - divider.rect.midX)
                : abs(location.y - divider.rect.midY)
            let intent = FleetCanvasDropIntent.sibling(
                path: divider.path,
                index: divider.leadingIndex + 1
            )
            if best == nil || distance < best!.distance {
                best = (distance, intent)
            }
        }
        return best?.intent
    }

    private static func cardIntent(
        at location: CGPoint,
        solution: FleetCanvasLayoutSolution
    ) -> FleetCanvasDropIntent? {
        guard let frame = solution.frames.first(where: { $0.rect.contains(location) }) else {
            return nil
        }
        let local = CGPoint(x: location.x - frame.rect.minX, y: location.y - frame.rect.minY)
        return .group(
            workspaceId: frame.workspaceId,
            edge: FleetCanvasDropTarget.edge(location: local, size: frame.rect.size)
        )
    }
}
