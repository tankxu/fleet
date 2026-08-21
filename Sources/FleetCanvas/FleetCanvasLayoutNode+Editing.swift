import CoreGraphics
import Foundation

extension FleetCanvasLayoutNode {
    /// Groups `id` with `target`, on `edge` of it.
    ///
    /// Dropping *onto a card* always groups; the edge only picks the group's axis
    /// and which member comes first. Rearranging at an existing level is the gap
    /// drops' job (``moving(_:intoContainerAt:atIndex:)``) — splitting the two
    /// intents by target is what makes "join this card" and "sit beside it"
    /// distinguishable, and what makes leaving a group possible at all.
    func moving(
        _ id: UUID,
        nextTo target: UUID,
        edge: FleetCanvasLayoutEdge
    ) -> FleetCanvasLayoutNode {
        guard id != target, workspaceIds.contains(target) else { return self }
        guard let pruned = removing(id) ?? FleetCanvasLayoutNode.workspace(id) as FleetCanvasLayoutNode? else {
            return self
        }
        // Removing may have collapsed the container the target lives in, so the
        // insertion is resolved against the pruned tree, not the original.
        guard pruned.workspaceIds.contains(target) else { return self }
        return pruned.placing(id, nextTo: target, edge: edge)
    }

    private func placing(
        _ id: UUID,
        nextTo target: UUID,
        edge: FleetCanvasLayoutEdge
    ) -> FleetCanvasLayoutNode {
        switch self {
        case let .workspace(existing):
            // A lone card: pair with it, since there is no container to reorder in.
            guard existing == target else { return self }
            return grouped(target: self, with: id, edge: edge)
        case let .container(axis, members, weights):
            guard let index = members.firstIndex(where: { $0.workspaceIds.contains(target) }) else {
                return self
            }
            let fractions = Self.fractions(weights: weights, memberCount: members.count)
            let member = members[index]

            // The target is deeper in: recurse, unless this container is the one
            // whose axis matches the drop and the target is a direct member.
            if !member.isLeaf, !(member.workspaceIds == [target]) {
                var updated = members
                updated[index] = member.placing(id, nextTo: target, edge: edge)
                return .container(axis: axis, members: updated, weights: fractions)
            }

            // The member is replaced by a container holding both, keeping the space
            // it already occupied. This applies on every edge: a drop onto a card
            // is a request to pair with that card, whichever side it lands on.
            var updated = members
            updated[index] = grouped(target: member, with: id, edge: edge)
            return .container(axis: axis, members: updated, weights: fractions)
        }
    }

    private func grouped(
        target: FleetCanvasLayoutNode,
        with id: UUID,
        edge: FleetCanvasLayoutEdge
    ) -> FleetCanvasLayoutNode {
        let newcomer = FleetCanvasLayoutNode.workspace(id)
        let members = edge.placesFirst ? [newcomer, target] : [target, newcomer]
        return .container(axis: edge.axis, members: members, weights: [0.5, 0.5])
    }

    /// Moves `id` to `index` among the members of the container at `path`.
    ///
    /// This is the operation a gap drop performs, and the only way to leave a
    /// group: dropping onto a card can at best rearrange that card's own
    /// container, so without an insertion point that names a *container* a card
    /// could never climb back out to an outer level.
    func moving(
        _ id: UUID,
        intoContainerAt path: FleetCanvasLayoutPath,
        atIndex index: Int
    ) -> FleetCanvasLayoutNode {
        guard workspaceIds.contains(id) else { return self }
        guard let pruned = removing(id) else { return self }
        // Removing the card may have collapsed the very container the gap belonged
        // to, in which case the drop is a no-op rather than a guess.
        guard case .container = pruned.node(at: path) else { return self }
        return pruned.insertingMember(.workspace(id), atPath: path, index: index)
    }

    func insertingMember(
        _ member: FleetCanvasLayoutNode,
        atPath path: FleetCanvasLayoutPath,
        index: Int
    ) -> FleetCanvasLayoutNode {
        guard case let .container(axis, members, weights) = self else { return self }
        let fractions = Self.fractions(weights: weights, memberCount: members.count)
        guard let step = path.indices.first else {
            let insertionIndex = min(max(index, 0), members.count)
            // The newcomer takes an equal share and everyone else scales down, so a
            // row of equal cards stays equal.
            let newShare = 1 / CGFloat(members.count + 1)
            let scale = 1 - newShare
            var updatedMembers = members
            var updatedWeights = fractions.map { $0 * scale }
            updatedMembers.insert(member, at: insertionIndex)
            updatedWeights.insert(newShare, at: insertionIndex)
            return .container(axis: axis, members: updatedMembers, weights: updatedWeights)
        }
        guard members.indices.contains(step) else { return self }
        var updatedMembers = members
        updatedMembers[step] = members[step].insertingMember(
            member,
            atPath: FleetCanvasLayoutPath(indices: Array(path.indices.dropFirst())),
            index: index
        )
        return .container(axis: axis, members: updatedMembers, weights: fractions)
    }

    /// Appends `id` as a member of the root container, so a new workspace shares
    /// the board evenly instead of halving one card.
    func appendingToRoot(_ id: UUID) -> FleetCanvasLayoutNode {
        switch self {
        case .workspace:
            return .container(axis: .horizontal, members: [self, .workspace(id)], weights: [0.5, 0.5])
        case let .container(axis, members, weights):
            let fractions = Self.fractions(weights: weights, memberCount: members.count)
            // Every existing member gives up an equal slice, which keeps a row of
            // equal cards equal as it grows.
            let newShare = 1 / CGFloat(members.count + 1)
            let scale = 1 - newShare
            return .container(
                axis: axis,
                members: members + [.workspace(id)],
                weights: fractions.map { $0 * scale } + [newShare]
            )
        }
    }

    /// Path of the leaf holding `id`.
    func path(of id: UUID) -> FleetCanvasLayoutPath? {
        switch self {
        case let .workspace(existing):
            return existing == id ? .root : nil
        case let .container(_, members, _):
            for (index, member) in members.enumerated() {
                if let sub = member.path(of: id) {
                    return FleetCanvasLayoutPath(indices: [index] + sub.indices)
                }
            }
            return nil
        }
    }

    /// Whether `id` sits inside a nested container rather than directly in the
    /// root — that is, whether it is in a group it could leave.
    func isInsideGroup(_ id: UUID) -> Bool {
        (path(of: id)?.indices.count ?? 0) > 1
    }

    /// Collects `ids` into one container, placed where the first of them was.
    ///
    /// The menu counterpart of dragging one card onto another: it works for more
    /// than two cards and needs no precise drop. Built *out of* the drag and gap
    /// operations rather than beside them, so "group from the menu" and "group by
    /// dragging" cannot drift apart — including the weights they leave behind.
    func grouping(_ ids: [UUID], axis: FleetCanvasSplitAxis) -> FleetCanvasLayoutNode {
        // Layout order, not selection order, so the group reads the way the board
        // already reads.
        let ordered = workspaceIds.filter(ids.contains)
        guard ordered.count > 1, let anchor = ordered.first else { return self }

        // The first pair is exactly a drag of the second card onto the first.
        var tree = moving(
            ordered[1],
            nextTo: anchor,
            edge: axis == .vertical ? .bottom : .trailing
        )
        // Remaining cards join that same container, which is a gap drop.
        for (offset, id) in ordered.dropFirst(2).enumerated() {
            guard let anchorPath = tree.path(of: anchor), anchorPath.indices.count >= 1 else { break }
            let containerPath = FleetCanvasLayoutPath(indices: anchorPath.indices.dropLast())
            tree = tree.moving(id, intoContainerAt: containerPath, atIndex: 2 + offset)
        }
        return tree
    }

    /// Lifts `id` out of its group into the level above.
    ///
    /// The menu counterpart of dragging a card into an outer gap, for when the drag
    /// is fiddly. A card already at the root has nowhere to go.
    func liftingOutOfGroup(_ id: UUID) -> FleetCanvasLayoutNode {
        guard let leafPath = path(of: id), leafPath.indices.count > 1 else { return self }
        let parentIndices = Array(leafPath.indices.dropLast())
        let grandparentPath = FleetCanvasLayoutPath(indices: parentIndices.dropLast())
        let parentIndex = parentIndices[parentIndices.count - 1]
        return moving(id, intoContainerAt: grandparentPath, atIndex: parentIndex + 1)
    }

    /// Removes `id`, collapsing any container left with a single member so it does
    /// not add a pointless level. Returns `nil` when the tree becomes empty.
    func removing(_ id: UUID) -> FleetCanvasLayoutNode? {
        switch self {
        case let .workspace(existing):
            return existing == id ? nil : self
        case let .container(axis, members, weights):
            let fractions = Self.fractions(weights: weights, memberCount: members.count)
            var keptMembers: [FleetCanvasLayoutNode] = []
            var keptWeights: [CGFloat] = []
            for (index, member) in members.enumerated() {
                guard let pruned = member.removing(id) else { continue }
                keptMembers.append(pruned)
                keptWeights.append(fractions[index])
            }
            switch keptMembers.count {
            case 0: return nil
            case 1: return keptMembers[0]
            default: return .container(axis: axis, members: keptMembers, weights: keptWeights)
            }
        }
    }

    /// The node at `path`, or `nil` when the path does not exist.
    func node(at path: FleetCanvasLayoutPath) -> FleetCanvasLayoutNode? {
        guard let index = path.indices.first else { return self }
        guard case let .container(_, members, _) = self, members.indices.contains(index) else { return nil }
        return members[index].node(at: FleetCanvasLayoutPath(indices: Array(path.indices.dropFirst())))
    }

    /// The tree with one container's weights replaced.
    func settingWeights(_ weights: [CGFloat], at path: FleetCanvasLayoutPath) -> FleetCanvasLayoutNode {
        guard case let .container(axis, members, currentWeights) = self else { return self }
        guard let index = path.indices.first else {
            return .container(
                axis: axis,
                members: members,
                weights: Self.fractions(weights: weights, memberCount: members.count)
            )
        }
        guard members.indices.contains(index) else { return self }
        var updated = members
        updated[index] = members[index].settingWeights(
            weights,
            at: FleetCanvasLayoutPath(indices: Array(path.indices.dropFirst()))
        )
        return .container(axis: axis, members: updated, weights: currentWeights)
    }

    /// The tree with the container at `path` reset to an even split.
    func evenlyDistributing(at path: FleetCanvasLayoutPath) -> FleetCanvasLayoutNode {
        guard let container = node(at: path), case let .container(_, members, _) = container else { return self }
        return settingWeights(Array(repeating: 1, count: members.count), at: path)
    }

    /// The tree reconciled against the window's live workspace list: closed
    /// workspaces are pruned, new ones join the root container, and everything else
    /// keeps its place.
    ///
    /// The tree outlives the workspaces it describes, so this runs on every layout
    /// pass rather than trusting stored state.
    func reconciled(with workspaceIds: [UUID]) -> FleetCanvasLayoutNode? {
        let live = Set(workspaceIds)
        var tree: FleetCanvasLayoutNode? = self
        for stale in self.workspaceIds where !live.contains(stale) {
            tree = tree?.removing(stale)
        }
        let known = Set(tree?.workspaceIds ?? [])
        for id in workspaceIds where !known.contains(id) {
            tree = tree?.appendingToRoot(id) ?? .workspace(id)
        }
        return tree
    }

    /// Layout for `workspaceIds` when nothing is stored: one row of equal cards,
    /// wrapping into rows once a row would hold more than `maximumPerRow`.
    ///
    /// Equal-width cards are the useful default for a board of terminals, and this
    /// keeps them equal instead of decaying into halves of halves.
    static func balanced(workspaceIds: [UUID], maximumPerRow: Int = 3) -> FleetCanvasLayoutNode? {
        guard !workspaceIds.isEmpty else { return nil }
        if workspaceIds.count == 1 { return .workspace(workspaceIds[0]) }
        if workspaceIds.count <= maximumPerRow {
            return .container(
                axis: .horizontal,
                members: workspaceIds.map { .workspace($0) },
                weights: Array(repeating: 1, count: workspaceIds.count)
            )
        }
        let rowCount = Int((Double(workspaceIds.count) / Double(maximumPerRow)).rounded(.up))
        let perRow = Int((Double(workspaceIds.count) / Double(rowCount)).rounded(.up))
        var rows: [FleetCanvasLayoutNode] = []
        var remaining = workspaceIds
        while !remaining.isEmpty {
            let slice = Array(remaining.prefix(perRow))
            remaining = Array(remaining.dropFirst(perRow))
            rows.append(
                slice.count == 1
                    ? .workspace(slice[0])
                    : .container(
                        axis: .horizontal,
                        members: slice.map { .workspace($0) },
                        weights: Array(repeating: 1, count: slice.count)
                    )
            )
        }
        return .container(
            axis: .vertical,
            members: rows,
            weights: Array(repeating: 1, count: rows.count)
        )
    }
}
