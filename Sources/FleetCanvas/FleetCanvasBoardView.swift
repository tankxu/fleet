import AppKit
import CmuxAppKitSupportUI
import SwiftUI

/// The fleet canvas: every workspace in the window as a live card, arranged by a
/// binary layout tree.
///
/// The board owns the tree, drag state, and persistence; cards receive immutable
/// geometry plus closures, so nothing below the `ForEach` boundary holds the tab
/// manager.
struct FleetCanvasBoardView: View {
    @ObservedObject var tabManager: TabManager
    let appearance: WindowAppearanceSnapshot

    @AppStorage(FleetCanvasLayoutTreeStore.defaultsKey) private var storedTree = ""

    /// Tree while a divider is being dragged or a drop is being applied. Kept out
    /// of defaults so a drag does not write to disk on every pointer sample.
    @State private var liveTree: FleetCanvasLayoutNode?

    /// Container weights as of a divider drag's start, so cumulative gesture
    /// translation maps to absolute weights instead of compounding.
    @State private var dragBaseFractions: [CGFloat]?

    /// Where the pointer is during a drag, in canvas coordinates. Resolved into
    /// intent on demand rather than stored, so the highlight and the drop can
    /// never disagree.
    @State private var dropLocation: CGPoint?

    /// Cards marked for grouping. Kept separate from `tabManager.selectedTabId`,
    /// which is keyboard focus and must stay single — a board can have one focused
    /// workspace and several marked ones at the same time.
    @State private var multiSelection: Set<UUID> = []

    /// Intent reported by the AppKit pane drop target, for drops that land on a
    /// card's terminal area where SwiftUI never sees them.
    @State private var bridgedIntent: FleetCanvasDropIntent?

    private static let endThickness: CGFloat = 24

    /// Height of a card's own chrome: its header plus the pane's tab/action bar.
    /// Vertical dividers start below this so they cannot shadow either.
    private static let cardChromeHeight: CGFloat = 96

    private static let boardPadding: CGFloat = 16
    private static let spacing: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            let workspaces = tabManager.tabs
            let selectedWorkspaceId = tabManager.selectedTabId
            let tree = resolvedTree(for: workspaces.map(\.id))
            let canvas = CGRect(origin: .zero, size: proxy.size)
                .insetBy(dx: Self.boardPadding, dy: Self.boardPadding)
            let solution = tree?.solve(in: canvas, spacing: Self.spacing) ?? .empty
            let workspacesById = Dictionary(
                workspaces.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let intent = dropIntent(solution: solution, tree: tree, canvas: canvas)

            ZStack(alignment: .topLeading) {
                FleetCanvasGlassSurface(depth: .canvas)
                ForEach(solution.frames) { frame in
                    if let workspace = workspacesById[frame.workspaceId] {
                        card(
                            workspace: workspace,
                            selectedWorkspaceId: selectedWorkspaceId,
                            size: frame.rect.size,
                            dropEdge: groupEdge(in: intent, for: frame.workspaceId),
                            isInGroup: tree?.isInsideGroup(frame.workspaceId) ?? false,
                            tree: tree
                        )
                        .frame(width: frame.rect.width, height: frame.rect.height)
                        .offset(x: frame.rect.minX, y: frame.rect.minY)
                    }
                }
                ForEach(solution.dividers) { divider in
                    FleetCanvasResizeHandle(
                        axis: divider.axis == .horizontal ? .columns : .rows,
                        thickness: Self.spacing,
                        chromeInset: Self.cardChromeHeight,
                        onDrag: { delta in
                            applyDividerDrag(divider, delta: delta, tree: tree, committing: false)
                        },
                        onCommit: { delta in
                            applyDividerDrag(divider, delta: delta, tree: tree, committing: true)
                        },
                        onReset: { resetDivider(divider, tree: tree) }
                    )
                    .frame(width: divider.rect.width, height: divider.rect.height)
                    .offset(x: divider.rect.minX, y: divider.rect.minY)
                }
                // Insertion line for the resolved intent: a gap between members, or
                // one end of the board.
                if let insertion = insertionRect(for: intent, solution: solution, tree: tree, canvas: canvas) {
                    Capsule()
                        .fill(FleetCanvasTheme.reorderIndicator)
                        .frame(width: insertion.width, height: insertion.height)
                        .offset(x: insertion.minX, y: insertion.minY)
                        .allowsHitTesting(false)
                }
            }
            // One drop target for the whole board. Per-view drop areas cannot be
            // trusted here: cards and dividers are placed with `offset`, and each
            // divider carries an AppKit view that accepts hit testing so it can own
            // the resize cursor.
            .onReceive(NotificationCenter.default.publisher(for: FleetCanvasCardDropBridge.notificationName)) { notification in
                guard let report = FleetCanvasCardDropBridge.decode(notification) else { return }
                switch report.phase {
                case .hover:
                    guard let edge = report.edge else { return }
                    let intent = FleetCanvasDropIntent.group(workspaceId: report.workspaceId, edge: edge)
                    guard bridgedIntent != intent else { return }
                    bridgedIntent = intent
                case .exit:
                    bridgedIntent = nil
                case .perform:
                    guard let edge = report.edge, let tree else {
                        bridgedIntent = nil
                        return
                    }
                    let intent = FleetCanvasDropIntent.group(workspaceId: report.workspaceId, edge: edge)
                    bridgedIntent = nil
                    guard let draggedWorkspaceId else { return }
                    let updated = applying(intent, to: tree, draggedWorkspaceId: draggedWorkspaceId)
                    guard updated != tree else { return }
                    store(updated)
                    endWorkspaceDragRegistration()
                }
            }
            .onDrop(
                of: SidebarTabDragPayload.dropContentTypes,
                delegate: FleetCanvasBoardDropDelegate(
                    onLocationChange: { location in
                        guard dropLocation != location else { return }
                        dropLocation = location
                        if location == nil { endWorkspaceDragRegistration() }
                    },
                    onPerformDrop: { location in
                        commitDrop(
                            at: location,
                            solution: solution,
                            tree: tree,
                            canvas: canvas
                        )
                    }
                )
            )
        }
    }

    /// Intent for the current pointer position, or `nil` when no drag is over the
    /// board or the drop would change nothing.
    private func dropIntent(
        solution: FleetCanvasLayoutSolution,
        tree: FleetCanvasLayoutNode?,
        canvas: CGRect
    ) -> FleetCanvasDropIntent? {
        // A drop over a card's body arrives through the AppKit bridge; only the
        // seams, the board ends, and card headers reach SwiftUI directly.
        if let bridgedIntent, let tree, let draggedWorkspaceId {
            guard applying(bridgedIntent, to: tree, draggedWorkspaceId: draggedWorkspaceId) != tree else {
                return nil
            }
            return bridgedIntent
        }
        guard let dropLocation, let tree, let draggedWorkspaceId else { return nil }
        guard let intent = FleetCanvasDropResolver.intent(
            at: dropLocation,
            solution: solution,
            tree: tree,
            canvas: canvas,
            endThickness: Self.endThickness
        ) else { return nil }
        guard applying(intent, to: tree, draggedWorkspaceId: draggedWorkspaceId) != tree else { return nil }
        return intent
    }

    private func groupEdge(
        in intent: FleetCanvasDropIntent?,
        for workspaceId: UUID
    ) -> FleetCanvasLayoutEdge? {
        guard case let .group(targetId, edge) = intent, targetId == workspaceId else { return nil }
        return edge
    }

    /// Rectangle for the insertion line of a sibling drop.
    private func insertionRect(
        for intent: FleetCanvasDropIntent?,
        solution: FleetCanvasLayoutSolution,
        tree: FleetCanvasLayoutNode?,
        canvas: CGRect
    ) -> CGRect? {
        guard case let .sibling(path, index) = intent, let tree else { return nil }
        if let divider = solution.dividers.first(where: { $0.path == path && $0.leadingIndex + 1 == index }) {
            return divider.axis == .horizontal
                ? CGRect(x: divider.rect.midX - 1.5, y: divider.rect.minY + 6, width: 3, height: divider.rect.height - 12)
                : CGRect(x: divider.rect.minX + 6, y: divider.rect.midY - 1.5, width: divider.rect.width - 12, height: 3)
        }
        // A board end: draw along the canvas edge the drop would insert at.
        guard path == .root, let axis = tree.containerAxis else { return nil }
        let atStart = index == 0
        switch axis {
        case .horizontal:
            let x = atStart ? canvas.minX - 5 : canvas.maxX + 2
            return CGRect(x: x, y: canvas.minY + 6, width: 3, height: canvas.height - 12)
        case .vertical:
            let y = atStart ? canvas.minY - 5 : canvas.maxY + 2
            return CGRect(x: canvas.minX + 6, y: y, width: canvas.width - 12, height: 3)
        }
    }

    /// The tree that `intent` would produce.
    private func applying(
        _ intent: FleetCanvasDropIntent,
        to tree: FleetCanvasLayoutNode,
        draggedWorkspaceId: UUID
    ) -> FleetCanvasLayoutNode {
        switch intent {
        case let .sibling(path, index):
            return tree.moving(draggedWorkspaceId, intoContainerAt: path, atIndex: index)
        case let .group(targetId, edge):
            guard targetId != draggedWorkspaceId else { return tree }
            return tree.moving(draggedWorkspaceId, nextTo: targetId, edge: edge)
        }
    }

    /// Clears the shared drag registration so the portal stops passing hit
    /// testing through once the drag is over.
    private func endWorkspaceDragRegistration() {
        guard let draggedWorkspaceId else { return }
        AppDelegate.shared?.sidebarWorkspaceDragRegistry.end(workspaceId: draggedWorkspaceId)
    }

    private func commitDrop(
        at location: CGPoint,
        solution: FleetCanvasLayoutSolution,
        tree: FleetCanvasLayoutNode?,
        canvas: CGRect
    ) -> Bool {
        dropLocation = nil
        defer { endWorkspaceDragRegistration() }
        guard let tree,
              let draggedWorkspaceId,
              let intent = FleetCanvasDropResolver.intent(
                  at: location,
                  solution: solution,
                  tree: tree,
                  canvas: canvas,
                  endThickness: Self.endThickness
              )
        else { return false }
        let updated = applying(intent, to: tree, draggedWorkspaceId: draggedWorkspaceId)
        guard updated != tree else { return false }
        store(updated)
        return true
    }

    private func card(
        workspace: Workspace,
        selectedWorkspaceId: UUID?,
        size: CGSize,
        dropEdge: FleetCanvasLayoutEdge?,
        isInGroup: Bool,
        tree: FleetCanvasLayoutNode?
    ) -> some View {
        let workspaceId = workspace.id
        return FleetWorkspaceCard(
            workspace: workspace,
            isSelected: workspaceId == selectedWorkspaceId,
            appearance: appearance,
            size: size,
            dropEdge: dropEdge,
            isMultiSelected: multiSelection.contains(workspaceId),
            isInGroup: isInGroup,
            multiSelectionCount: multiSelection.count,
            onSelect: { [weak workspace] in
                guard let workspace else { return }
                // A plain click is focus, so it also ends any grouping selection —
                // leaving a stale dashed ring around cards would make the next
                // context menu act on a selection the user forgot about.
                multiSelection.removeAll()
                tabManager.selectWorkspace(workspace)
            },
            onToggleMultiSelection: {
                if multiSelection.contains(workspaceId) {
                    multiSelection.remove(workspaceId)
                } else {
                    multiSelection.insert(workspaceId)
                }
            },
            onGroupSelection: { axis in
                groupMultiSelection(axis: axis, tree: tree)
            },
            onExitGroup: {
                guard let tree else { return }
                let updated = tree.liftingOutOfGroup(workspaceId)
                guard updated != tree else { return }
                store(updated)
            },
            onRenameCommit: { title in
                // Same mutation path as the sidebar, command palette, and CLI, so a
                // rename here also renames a mirrored remote tmux session and blocks
                // later auto-naming from overwriting it.
                tabManager.setCustomTitle(tabId: workspaceId, title: title, source: .user)
            },
            onRequestClose: { [weak workspace] in
                guard let workspace else { return }
                // Same path as the sidebar close button and the close shortcut, so a
                // pinned workspace still asks and a running process still warns.
                tabManager.closeWorkspaceWithConfirmation(workspace)
            }
        )
    }

    private func groupMultiSelection(axis: FleetCanvasSplitAxis, tree: FleetCanvasLayoutNode?) {
        guard let tree, multiSelection.count > 1 else { return }
        let updated = tree.grouping(Array(multiSelection), axis: axis)
        multiSelection.removeAll()
        guard updated != tree else { return }
        store(updated)
    }

    /// The tree in effect: a live edit, else what was stored, else a generated
    /// layout — always reconciled against the window's current workspaces, since
    /// the tree outlives the workspaces it describes.
    private func resolvedTree(for workspaceIds: [UUID]) -> FleetCanvasLayoutNode? {
        let base = liveTree
            ?? FleetCanvasLayoutTreeStore.tree(in: storedTree)
            ?? FleetCanvasLayoutNode.balanced(workspaceIds: workspaceIds)
        return base?.reconciled(with: workspaceIds)
    }

    /// The dragged workspace, read from the drag pasteboard rather than from view
    /// state: the pasteboard is the one identity that survives a whole native drag
    /// session, including drags started in the sidebar.
    private var draggedWorkspaceId: UUID? {
        let raw = NSPasteboard(name: .drag).string(
            forType: NSPasteboard.PasteboardType(SidebarTabDragPayload.typeIdentifier)
        )
        return SidebarTabDragPayload.workspaceId(fromPasteboardString: raw)
    }

    private func applyDividerDrag(
        _ divider: FleetCanvasLayoutDivider,
        delta: CGFloat,
        tree: FleetCanvasLayoutNode?,
        committing: Bool
    ) {
        guard let tree else { return }
        // The gesture reports cumulative translation, so every sample is measured
        // from the weights as of the drag's start.
        let base = dragBaseFractions ?? divider.fractions
        if dragBaseFractions == nil { dragBaseFractions = base }
        guard let updatedFractions = FleetCanvasLayoutWeightDrag.adjusted(
            fractions: base,
            leadingIndex: divider.leadingIndex,
            delta: delta,
            usableLength: divider.usableLength
        ) else { return }
        let updated = tree.settingWeights(updatedFractions, at: divider.path)
        guard committing else {
            liveTree = updated
            return
        }
        dragBaseFractions = nil
        store(updated)
    }

    private func resetDivider(_ divider: FleetCanvasLayoutDivider, tree: FleetCanvasLayoutNode?) {
        guard let tree else { return }
        dragBaseFractions = nil
        store(tree.evenlyDistributing(at: divider.path))
    }

    private func store(_ tree: FleetCanvasLayoutNode) {
        liveTree = nil
        storedTree = FleetCanvasLayoutTreeStore.encode(tree)
        syncWorkspaceOrder(to: tree)
    }

    /// Pushes the board's visual order back into the workspace list.
    ///
    /// Without this the board grows a second, private ordering: the canvas reads
    /// left-to-right off the layout tree while `Next Workspace`, the numbered
    /// selection shortcuts, and the sidebar all cycle through `tabManager.tabs`.
    /// Rearranging cards then makes "next" jump to whatever is visually left,
    /// because the two orders have drifted apart. One order, owned by the tab
    /// manager, is the only way those stay honest.
    ///
    /// The reorder goes through the shared batch API so pinned-workspace and group
    /// placement rules still apply; a rejected plan simply leaves the list as it
    /// was rather than forcing an illegal order.
    private func syncWorkspaceOrder(to tree: FleetCanvasLayoutNode) {
        let layoutOrder = tree.workspaceIds
        guard layoutOrder != tabManager.tabs.map(\.id) else { return }
        _ = tabManager.reorderWorkspaces(orderedWorkspaceIds: layoutOrder)
    }
}
