import CoreGraphics
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// The resolver replaced per-view drop targets, so these are the tests that stand
/// in for "can I actually drop between two cards" — a question SwiftUI hit
/// geometry answered wrong when each card and divider owned its own drop area.
@Suite("Fleet canvas drop resolver")
struct FleetCanvasDropResolverTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private let canvas = CGRect(x: 16, y: 16, width: 1568, height: 868)
    private let spacing: CGFloat = 16
    private let endThickness: CGFloat = 24

    private func row(_ ids: [UUID]) -> FleetCanvasLayoutNode {
        .container(
            axis: .horizontal,
            members: ids.map { .workspace($0) },
            weights: Array(repeating: 1, count: ids.count)
        )
    }

    private func resolve(
        _ location: CGPoint,
        tree: FleetCanvasLayoutNode
    ) -> FleetCanvasDropIntent? {
        FleetCanvasDropResolver.intent(
            at: location,
            solution: tree.solve(in: canvas, spacing: spacing),
            tree: tree,
            canvas: canvas,
            endThickness: endThickness
        )
    }

    @Test("Dropping in the gap between two cards inserts between them")
    func gapBetweenCardsInsertsThere() {
        let tree = row([a, b, c])
        let solution = tree.solve(in: canvas, spacing: spacing)
        let gap = solution.dividers[0].rect

        let intent = resolve(CGPoint(x: gap.midX, y: gap.midY), tree: tree)

        #expect(intent == .sibling(path: .root, index: 1))
    }

    @Test("The gap is catchable slightly outside the visible seam")
    func gapHasTolerance() {
        let tree = row([a, b])
        let solution = tree.solve(in: canvas, spacing: spacing)
        let gap = solution.dividers[0].rect

        // A few points into the neighbouring card still targets the seam: a 16pt
        // seam between two huge cards is otherwise a coin flip.
        let intent = resolve(CGPoint(x: gap.minX - 8, y: gap.midY), tree: tree)

        #expect(intent == .sibling(path: .root, index: 1))
    }

    @Test("A gap inside a nested group targets that group's level")
    func nestedGapTargetsItsOwnContainer() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )
        let solution = tree.solve(in: canvas, spacing: spacing)
        guard let inner = solution.dividers.first(where: { $0.axis == .vertical }) else {
            Issue.record("expected a vertical divider")
            return
        }

        let intent = resolve(CGPoint(x: inner.rect.midX, y: inner.rect.midY), tree: tree)

        #expect(intent == .sibling(path: FleetCanvasLayoutPath(indices: [1]), index: 1))
    }

    @Test("The leading edge of the board inserts at the very start")
    func leadingEdgeInsertsFirst() {
        let tree = row([a, b, c])

        let intent = resolve(CGPoint(x: canvas.minX + 4, y: canvas.midY), tree: tree)

        #expect(intent == .sibling(path: .root, index: 0))
    }

    @Test("The trailing edge of the board inserts at the very end")
    func trailingEdgeInsertsLast() {
        let tree = row([a, b, c])

        let intent = resolve(CGPoint(x: canvas.maxX - 4, y: canvas.midY), tree: tree)

        #expect(intent == .sibling(path: .root, index: 3))
    }

    @Test("A stacked board takes its ends along the vertical axis")
    func verticalBoardUsesTopAndBottomEnds() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .vertical,
            members: [.workspace(a), .workspace(b)],
            weights: [1, 1]
        )

        #expect(resolve(CGPoint(x: canvas.midX, y: canvas.minY + 4), tree: tree) == .sibling(path: .root, index: 0))
        #expect(resolve(CGPoint(x: canvas.midX, y: canvas.maxY - 4), tree: tree) == .sibling(path: .root, index: 2))
    }

    @Test("Dropping well inside a card groups with it, and the edge follows the pointer")
    func insideCardGroups() {
        let tree = row([a, b])
        let solution = tree.solve(in: canvas, spacing: spacing)
        let first = solution.frames[0].rect

        let top = resolve(CGPoint(x: first.midX, y: first.minY + 20), tree: tree)
        let bottom = resolve(CGPoint(x: first.midX, y: first.maxY - 20), tree: tree)

        #expect(top == .group(workspaceId: a, edge: .top))
        #expect(bottom == .group(workspaceId: a, edge: .bottom))
    }

    @Test("Seams and ends win over the cards they sit between")
    func insertionPointsBeatCards() {
        let tree = row([a, b])
        let solution = tree.solve(in: canvas, spacing: spacing)
        let gap = solution.dividers[0].rect

        // Just inside the right-hand card, but within the seam's tolerance.
        let intent = resolve(CGPoint(x: gap.maxX + 6, y: gap.midY), tree: tree)

        #expect(intent == .sibling(path: .root, index: 1))
    }

    @Test("A single card has no ends to drop at, only itself")
    func singleCardHasNoEnds() {
        let tree = FleetCanvasLayoutNode.workspace(a)

        let intent = resolve(CGPoint(x: canvas.minX + 4, y: canvas.midY), tree: tree)

        #expect(intent == .group(workspaceId: a, edge: .leading))
    }

    @Test("A point outside the board resolves to nothing")
    func outsideBoardResolvesToNothing() {
        let tree = row([a, b])

        #expect(resolve(CGPoint(x: -50, y: -50), tree: tree) == nil)
    }
}
