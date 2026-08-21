import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

/// Menu-driven grouping exists because a drag can be fiddly, so it has to reach
/// the same tree shapes dragging does — these tests pin that equivalence.
@Suite("Fleet canvas grouping commands")
struct FleetCanvasGroupingTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private let d = UUID()

    private func row(_ ids: [UUID]) -> FleetCanvasLayoutNode {
        .container(
            axis: .horizontal,
            members: ids.map { .workspace($0) },
            weights: Array(repeating: 1, count: ids.count)
        )
    }

    @Test("Grouping two cards nests them where the first one sat")
    func groupingTwoCards() {
        let grouped = row([a, b, c]).grouping([b, c], axis: .vertical)

        guard case let .container(axis, members, _) = grouped else {
            Issue.record("expected a container")
            return
        }
        #expect(axis == .horizontal)
        #expect(members.count == 2)
        #expect(members[0] == .workspace(a))
        guard case let .container(innerAxis, innerMembers, _) = members[1] else {
            Issue.record("expected a nested group")
            return
        }
        #expect(innerAxis == .vertical)
        #expect(innerMembers == [.workspace(b), .workspace(c)])
    }

    @Test("Grouping accepts more than two cards, which dragging cannot")
    func groupingThreeCards() {
        let grouped = row([a, b, c, d]).grouping([b, c, d], axis: .vertical)

        guard case let .container(_, members, _) = grouped, members.count == 2 else {
            Issue.record("expected two top-level members")
            return
        }
        #expect(members[1].count == 3)
    }

    @Test("Members follow layout order, not the order they were selected")
    func groupingUsesLayoutOrder() {
        let grouped = row([a, b, c]).grouping([c, a], axis: .vertical)

        #expect(grouped.workspaceIds.prefix(2) == [a, c])
    }

    @Test("Grouping fewer than two cards changes nothing")
    func groupingSingleCardIsNoOp() {
        let tree = row([a, b])

        #expect(tree.grouping([a], axis: .vertical) == tree)
        #expect(tree.grouping([], axis: .vertical) == tree)
    }

    @Test("Grouping every card just nests the whole board once")
    func groupingEverything() {
        let grouped = row([a, b]).grouping([a, b], axis: .vertical)

        #expect(grouped.workspaceIds == [a, b])
        #expect(grouped.containerAxis == .vertical)
    }

    @Test("Exiting a group lifts the card to the level above")
    func exitGroupLiftsCard() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )
        let lifted = tree.liftingOutOfGroup(c)

        guard case let .container(_, members, _) = lifted else {
            Issue.record("expected a container")
            return
        }
        // The group it left had only b remaining, so it collapsed.
        let allLeaves = members.allSatisfy(\.isLeaf)
        #expect(allLeaves)
        #expect(lifted.workspaceIds == [a, b, c])
    }

    @Test("Exiting a group lands next to the group, not at the far end")
    func exitGroupLandsBesideItsGroup() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .container(axis: .vertical, members: [.workspace(a), .workspace(b)], weights: [1, 1]),
                .workspace(c),
                .workspace(d),
            ],
            weights: [1, 1, 1]
        )
        let lifted = tree.liftingOutOfGroup(b)

        #expect(lifted.workspaceIds == [a, b, c, d])
    }

    @Test("A card already at the root cannot exit a group")
    func rootCardCannotExit() {
        let tree = row([a, b])

        #expect(tree.liftingOutOfGroup(a) == tree)
        #expect(!tree.isInsideGroup(a))
    }

    @Test("Group membership is detectable so the menu item can hide itself")
    func groupMembershipIsDetectable() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )

        #expect(!tree.isInsideGroup(a))
        #expect(tree.isInsideGroup(b))
        #expect(tree.isInsideGroup(c))
    }

    @Test("Menu grouping and drag grouping produce the same shape for two cards")
    func menuMatchesDrag() {
        let tree = row([a, b, c])
        let dragged = tree.moving(c, nextTo: b, edge: .bottom)
        let grouped = tree.grouping([b, c], axis: .vertical)

        #expect(dragged == grouped)
    }
}
