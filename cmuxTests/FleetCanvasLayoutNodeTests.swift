import CoreGraphics
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas layout tree")
struct FleetCanvasLayoutNodeTests {
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

    // MARK: - Default shape

    @Test("Three workspaces are one row of equal cards")
    func threeWorkspacesShareOneRow() {
        guard let tree = FleetCanvasLayoutNode.balanced(workspaceIds: [a, b, c]) else {
            Issue.record("expected a value for tree")
            return
        }

        guard case let .container(axis, members, weights) = tree else {
            Issue.record("expected a container")
            return
        }
        #expect(axis == .horizontal)
        #expect(members == [.workspace(a), .workspace(b), .workspace(c)])
        let fractions = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 3)
        let satisfiesAll0 = fractions.allSatisfy { abs($0 - 1.0 / 3) < 0.000_001 }
        #expect(satisfiesAll0)
    }

    @Test("More than a row's worth wraps into rows instead of halving cards")
    func manyWorkspacesWrap() {
        let ids = [a, b, c, d]
        guard let tree = FleetCanvasLayoutNode.balanced(workspaceIds: ids, maximumPerRow: 3) else {
            Issue.record("expected a value for tree")
            return
        }

        guard case let .container(axis, rows, _) = tree else {
            Issue.record("expected a container of rows")
            return
        }
        #expect(axis == .vertical)
        #expect(rows.count == 2)
        #expect(tree.workspaceIds == ids)
    }

    @Test("A new workspace shares the row evenly rather than halving one card")
    func appendKeepsCardsEqual() {
        let tree = row([a, b, c]).appendingToRoot(d)

        guard case let .container(_, members, weights) = tree else {
            Issue.record("expected a container")
            return
        }
        #expect(members.count == 4)
        let fractions = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 4)
        let satisfiesAll1 = fractions.allSatisfy { abs($0 - 0.25) < 0.000_001 }
        #expect(satisfiesAll1)
    }

    // MARK: - Reordering (gap drops)

    @Test("A gap drop reorders inside the container without grouping")
    func gapDropReorders() {
        let tree = row([a, b, c])
        let moved = tree.moving(c, intoContainerAt: .root, atIndex: 0)

        #expect(moved.workspaceIds == [c, a, b])
        guard case let .container(_, members, _) = moved else {
            Issue.record("expected a container")
            return
        }
        let allLeaves = members.allSatisfy(\.isLeaf)
        #expect(allLeaves)
    }

    @Test("A gap drop lifts a card out of a group")
    func gapDropLeavesGroup() {
        // One card left, two stacked right.
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )

        // Dropping c into the root container's gap makes it a sibling of a, and the
        // group it left collapses because only b remains.
        let moved = tree.moving(c, intoContainerAt: .root, atIndex: 1)

        guard case let .container(axis, members, _) = moved else {
            Issue.record("expected a container")
            return
        }
        #expect(axis == .horizontal)
        let allLeaves = members.allSatisfy(\.isLeaf)
        #expect(allLeaves)
        #expect(moved.workspaceIds == [a, c, b])
    }

    @Test("A gap drop keeps members equal when they were equal")
    func gapDropKeepsEqualShares() {
        let moved = row([a, b, c]).moving(c, intoContainerAt: .root, atIndex: 0)

        guard case let .container(_, _, weights) = moved else {
            Issue.record("expected a container")
            return
        }
        let fractions = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 3)
        let isEven = fractions.allSatisfy { abs($0 - 1.0 / 3) < 0.01 }
        #expect(isEven)
    }

    @Test("A gap whose container disappeared is a no-op")
    func gapDropIntoVanishedContainerIsNoOp() {
        // Removing b collapses the inner container, so a path into it is stale.
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )
        let stalePath = FleetCanvasLayoutPath(indices: [1])

        #expect(tree.moving(b, intoContainerAt: stalePath, atIndex: 0) == tree)
    }

    // MARK: - Grouping

    @Test("A drop across the container's axis groups the two cards")
    func dropAcrossAxisGroups() {
        let tree = row([a, b, c])
        let grouped = tree.moving(c, nextTo: b, edge: .bottom)

        guard case let .container(_, members, _) = grouped, members.count == 2 else {
            Issue.record("expected the row to shrink to two members")
            return
        }
        #expect(members[0] == .workspace(a))
        guard case let .container(innerAxis, innerMembers, _) = members[1] else {
            Issue.record("expected b to become a group")
            return
        }
        #expect(innerAxis == .vertical)
        #expect(innerMembers == [.workspace(b), .workspace(c)])
    }

    @Test("One card left and two stacked right is reachable in one drop")
    func oneLeftTwoRightInOneDrop() {
        let grouped = row([a, b, c]).moving(c, nextTo: b, edge: .bottom)

        #expect(grouped.workspaceIds == [a, b, c])
        #expect(grouped.count == 3)
    }

    @Test("The group keeps the space the target already occupied")
    func groupInheritsTargetShare() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b)],
            weights: [0.7, 0.3]
        )
        let grouped = tree.moving(c, nextTo: b, edge: .top)

        guard case let .container(_, _, weights) = grouped else {
            Issue.record("expected a container")
            return
        }
        let fractions = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 2)
        #expect(abs(fractions[0] - 0.7) < 0.01)
    }

    @Test("Groups nest without limit")
    func groupsNestWithoutLimit() {
        var tree = row([a, b])
        var ids = [a, b]
        for _ in 0 ..< 5 {
            let id = UUID()
            tree = tree.appendingToRoot(id)
            tree = tree.moving(id, nextTo: ids[ids.count - 1], edge: .bottom)
            ids.append(id)
        }

        #expect(tree.count == ids.count)
        #expect(Set(tree.workspaceIds) == Set(ids))
    }

    @Test("Moving a card moves it instead of duplicating it")
    func movingDoesNotDuplicate() {
        let moved = row([a, b, c]).moving(a, nextTo: c, edge: .bottom)

        #expect(moved.count == 3)
        #expect(Set(moved.workspaceIds) == Set([a, b, c]))
    }

    // MARK: - Removal

    @Test("Removing a card collapses a container left with one member")
    func removalCollapsesSingleMemberContainer() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )

        // Removing c leaves the inner container with just b, which collapses away.
        guard let pruned = tree.removing(c) else {
            Issue.record("expected a value for pruned")
            return
        }
        guard case let .container(_, members, _) = pruned else {
            Issue.record("expected a container")
            return
        }
        #expect(members == [.workspace(a), .workspace(b)])
    }

    @Test("Removing from a row keeps the row and the other members' shares")
    func removalKeepsRow() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b), .workspace(c)],
            weights: [0.5, 0.25, 0.25]
        )
        guard let pruned = tree.removing(b) else {
            Issue.record("expected a value for pruned")
            return
        }

        guard case let .container(_, members, weights) = pruned else {
            Issue.record("expected a container")
            return
        }
        #expect(members == [.workspace(a), .workspace(c)])
        let fractions = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 2)
        #expect(fractions[0] > fractions[1])
    }

    @Test("Removing the last card empties the tree")
    func removingLastCardEmptiesTree() {
        #expect(FleetCanvasLayoutNode.workspace(a).removing(a) == nil)
    }

    // MARK: - Reconciliation

    @Test("Closed workspaces are pruned and new ones join the root row")
    func reconciliationTracksWorkspaces() {
        let tree = row([a, b, c])
        guard let reconciled = tree.reconciled(with: [a, c, d]) else {
            Issue.record("expected a value for reconciled")
            return
        }

        #expect(Set(reconciled.workspaceIds) == Set([a, c, d]))
    }

    @Test("Reconciliation leaves an unchanged workspace set alone")
    func reconciliationIsStable() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .vertical,
            members: [.workspace(a), .workspace(b)],
            weights: [0.25, 0.75]
        )

        guard let reconciled = tree.reconciled(with: [a, b]) else {
            Issue.record("expected a value for reconciled")
            return
        }
        #expect(reconciled == tree)
    }

    @Test("A tree describing only closed workspaces rebuilds from the live list")
    func fullyStaleTreeRebuilds() {
        guard let reconciled = FleetCanvasLayoutNode.workspace(a).reconciled(with: [b, c]) else {
            Issue.record("expected a value for reconciled")
            return
        }

        #expect(Set(reconciled.workspaceIds) == Set([b, c]))
    }

    // MARK: - Weights

    @Test("Weights are fitted when they do not match the member count")
    func weightsAreFitted() {
        #expect(FleetCanvasLayoutNode.fractions(weights: [], memberCount: 3).count == 3)
        #expect(FleetCanvasLayoutNode.fractions(weights: [1, 1], memberCount: 4).count == 4)
        #expect(FleetCanvasLayoutNode.fractions(weights: [1, 2, 3, 4], memberCount: 2).count == 2)
        let junk = FleetCanvasLayoutNode.fractions(weights: [.nan, -1, 0, 2], memberCount: 2)
        let satisfiesAll3 = junk.allSatisfy { $0.isFinite && $0 > 0 }
        #expect(satisfiesAll3)
        #expect(abs(junk.reduce(0, +) - 1) < 0.000_001)
    }

    @Test("Weights apply to the addressed container only")
    func weightsApplyToAddressedContainer() {
        let inner = FleetCanvasLayoutNode.container(
            axis: .vertical,
            members: [.workspace(b), .workspace(c)],
            weights: [1, 1]
        )
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), inner],
            weights: [1, 1]
        )
        let updated = tree.settingWeights([0.8, 0.2], at: FleetCanvasLayoutPath(indices: [1]))

        guard case let .container(_, outerMembers, outerWeights) = updated else {
            Issue.record("expected a container")
            return
        }
        #expect(FleetCanvasLayoutNode.fractions(weights: outerWeights, memberCount: 2)[0] == 0.5)
        guard case let .container(_, _, innerWeights) = outerMembers[1] else {
            Issue.record("expected a nested container")
            return
        }
        #expect(abs(FleetCanvasLayoutNode.fractions(weights: innerWeights, memberCount: 2)[0] - 0.8) < 0.000_001)
    }

    @Test("Distributing evenly resets one container")
    func evenDistributionResetsContainer() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b), .workspace(c)],
            weights: [0.6, 0.3, 0.1]
        )
        let reset = tree.evenlyDistributing(at: .root)

        guard case let .container(_, _, weights) = reset else {
            Issue.record("expected a container")
            return
        }
        let isEvenSplit = FleetCanvasLayoutNode.fractions(weights: weights, memberCount: 3).allSatisfy {
            abs($0 - 1.0 / 3) < 0.000_001
        }
        #expect(isEvenSplit)
    }
}
