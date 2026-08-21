import AppKit
import CmuxAppKitSupportUI
import SwiftUI

/// One workspace on the fleet canvas: a status header over the workspace's live
/// panel content.
///
/// Cards stay close to opaque while the board behind them is glass. That
/// contrast is the board's depth cue, and it is what keeps terminal text
/// readable over a translucent window.
struct FleetWorkspaceCard: View {
    @ObservedObject var workspace: Workspace
    let isSelected: Bool
    let appearance: WindowAppearanceSnapshot
    let size: CGSize
    let dropEdge: FleetCanvasLayoutEdge?
    /// Whether this card is part of the multi-selection used for grouping.
    let isMultiSelected: Bool
    /// Whether this card sits in a group it could leave.
    let isInGroup: Bool
    /// Number of cards in the multi-selection, for the menu's wording.
    let multiSelectionCount: Int
    let onSelect: () -> Void
    /// Adds or removes this card from the multi-selection.
    let onToggleMultiSelection: () -> Void
    /// Groups the current multi-selection along `axis`.
    let onGroupSelection: (FleetCanvasSplitAxis) -> Void
    /// Lifts this card out of its group.
    let onExitGroup: () -> Void
    /// Commits a rename. `nil` clears the custom title so the card goes back to
    /// deriving its own.
    let onRenameCommit: (String?) -> Void
    /// Closes the workspace, through the same confirmation path every other close
    /// entry point uses.
    let onRequestClose: () -> Void

    @State private var draftTitle: String?
    @State private var isTitleHovered = false
    @FocusState private var isTitleFieldFocused: Bool

    /// Agents observed on `panelId`, from restored snapshots and from live hook
    /// lifecycle keys. Both vocabularies resolve through the same catalog.
    private func agents(forPanelId panelId: UUID) -> [FleetWorkspaceAgentPresence] {
        var seenIds = Set<String>()
        var presences: [FleetWorkspaceAgentPresence] = []
        let identifiers = [workspace.restoredAgentSnapshotsByPanelId[panelId]?.kind.rawValue]
            .compactMap { $0 }
            + Array(workspace.agentLifecycleStatesByPanelId[panelId]?.keys ?? [:].keys)
        for identifier in identifiers {
            guard let presence = FleetWorkspaceAgentCatalog.presence(forIdentifier: identifier),
                  seenIds.insert(presence.agentId).inserted else { continue }
            presences.append(presence)
        }
        return presences
    }

    private var panelSnapshots: [FleetWorkspacePanelSnapshot] {
        workspace.orderedPanelIds.compactMap { panelId in
            guard let panel = workspace.panels[panelId] else { return nil }
            // `panelTitle` is the same resolution the pane's own tab uses: custom
            // title, then the title the terminal reports (which is where an
            // agent writes its session name), then the panel's static fallback.
            // Reading `displayTitle` directly skipped the middle one and left
            // every agent card labelled "Terminal".
            return FleetWorkspacePanelSnapshot(
                title: workspace.panelTitle(panelId: panelId) ?? panel.displayTitle,
                directory: (panel as? TerminalPanel)?.directory,
                agent: agents(forPanelId: panelId).first
            )
        }
    }

    private var identity: FleetWorkspaceCardIdentity {
        FleetWorkspaceCardIdentity.resolve(
            panels: panelSnapshots,
            workspaceTitle: workspace.title,
            workspaceDirectory: workspace.presentedCurrentDirectory,
            customTitle: workspace.customTitle
        )
    }

    private var completedAgentCount: Int {
        workspace.restoredAgentResumeStatesByPanelId.values.filter { $0 == .completedAgentExit }.count
    }

    private var runningAgentCount: Int {
        SidebarAgentActivitySummary.activeCodingAgentCount(
            statesByPanelId: workspace.agentLifecycleStatesByPanelId
        )
    }

    private var needsInputAgentCount: Int {
        workspace.agentLifecycleStatesByPanelId.values.reduce(0) { count, states in
            count + states.values.filter { $0 == .needsInput }.count
        }
    }

    private var agentCount: Int {
        let distinctPanelsWithAgents = workspace.orderedPanelIds.reduce(into: 0) { count, panelId in
            if !agents(forPanelId: panelId).isEmpty { count += 1 }
        }
        return max(distinctPanelsWithAgents, runningAgentCount + needsInputAgentCount + completedAgentCount)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FleetCanvasTheme.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .overlay(Color.white.opacity(0.08))
            WorkspaceContentView(
                workspace: workspace,
                isWorkspaceVisible: true,
                isWorkspaceInputActive: isSelected,
                rendersInactiveWorkspaceContent: true,
                onWorkspaceInputRequested: onSelect,
                rightSidebarOwnsInputFocus: false,
                isFullScreen: false,
                workspacePortalPriority: isSelected ? 2 : 0,
                windowAppearance: appearance,
                onThemeRefreshRequest: { _, _, _, _ in }
            )
        }
        .frame(width: size.width, height: size.height)
        .background(shape.fill(cardBackgroundColor))
        .clipShape(shape)
        .overlay {
            shape.stroke(
                isSelected ? FleetCanvasTheme.selectedCardBorder : FleetCanvasTheme.cardBorder,
                lineWidth: isSelected ? 2 : 1
            )
        }
        // Multi-selection reads as a dashed ring so it never looks like keyboard
        // focus, which the solid ring already means.
        .overlay {
            if isMultiSelected {
                shape.strokeBorder(
                    FleetCanvasTheme.accent,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
            }
        }
        // Insertion preview: the edge the dragged card would take, which is also
        // the side the new group's divider will sit on.
        .overlay(alignment: dropEdge.map(Self.alignment(for:)) ?? .center) {
            if let dropEdge {
                Capsule()
                    .fill(FleetCanvasTheme.reorderIndicator)
                    .frame(
                        width: dropEdge.axis == .horizontal ? 3 : nil,
                        height: dropEdge.axis == .horizontal ? nil : 3
                    )
                    .padding(dropEdge.axis == .horizontal ? .vertical : .horizontal, 6)
            }
        }
        .shadow(color: Color.black.opacity(0.34), radius: 14, y: 7)
    }

    private var header: some View {
        // Not a Button: the title inside has to accept clicks and text input of
        // its own, and a Button swallows both from its label.
        VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    FleetWorkspaceCardIconView(icon: identity.icon, isSelected: isSelected)
                    titleView
                    Spacer(minLength: 8)
                    Text(
                        String(
                            localized: "fleetCanvas.card.panelCount",
                            defaultValue: "\(workspace.panels.count) panels"
                        )
                    )
                    .cmuxFont(size: 10, weight: .medium)
                    .foregroundStyle(Color.secondary)
                }
                statusRow
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // One tap gesture that branches on the live modifier state. `TapGesture()
        // .modifiers(_:)` looked cleaner but only fires when the gesture *begins*
        // with the modifier held, and the plain tap on the same view wins the race
        // — the net effect was that only the title (which has its own gesture)
        // responded to Shift-click.
        .onTapGesture {
            let flags = NSEvent.modifierFlags
            // Shift and Command both extend the selection: a board has no linear
            // order for Shift to extend along, so both simply toggle this card.
            if flags.contains(.shift) || flags.contains(.command) {
                onToggleMultiSelection()
            } else {
                onSelect()
            }
        }
        .background(headerBackgroundColor)
        // Only the header carries the menu: the card's body is a terminal, and
        // right-clicking a terminal belongs to the terminal.
        .contextMenu {
            if multiSelectionCount > 1, isMultiSelected {
                Button(String(
                    localized: "fleetCanvas.menu.groupSelectionVertically",
                    defaultValue: "Group \(multiSelectionCount) Workspaces (Stacked)"
                )) {
                    onGroupSelection(.vertical)
                }
                Button(String(
                    localized: "fleetCanvas.menu.groupSelectionHorizontally",
                    defaultValue: "Group \(multiSelectionCount) Workspaces (Side by Side)"
                )) {
                    onGroupSelection(.horizontal)
                }
                Divider()
            }
            if isInGroup {
                Button(String(
                    localized: "fleetCanvas.menu.exitGroup",
                    defaultValue: "Exit Group"
                )) {
                    onExitGroup()
                }
                Divider()
            }
            Button(String(localized: "contextMenu.renameWorkspace", defaultValue: "Rename Workspace…")) {
                beginTitleEdit()
            }
            Divider()
            Button(
                String(localized: "contextMenu.closeWorkspace", defaultValue: "Close Workspace"),
                role: .destructive,
                action: onRequestClose
            )
        }
        // Only the header is draggable. The card body hosts an AppKit terminal
        // that owns its own mouse tracking, so a body-wide drag gesture would
        // either lose to the terminal or steal its selection drags.
        .onDrag {
            // Register the drag with the shared workspace-drag registry. The
            // terminal portal is an AppKit sibling that sits *above* the SwiftUI
            // board, so a drop over a card's body never reaches SwiftUI on its
            // own; cmux already solves this by letting the portal pass hit testing
            // through while a workspace drag is registered (see
            // `DragOverlayRoutingPolicy.shouldPassThroughTerminalPortalHitTesting`),
            // and the sidebar's own drags rely on exactly this. Without the
            // registration only the card header — the one strip the portal does not
            // cover — could accept a drop.
            AppDelegate.shared?.sidebarWorkspaceDragRegistry.begin(workspaceId: workspace.id)
            return SidebarTabDragPayload(tabId: workspace.id).provider()
        } preview: {
            FleetCanvasCardDragPreview(title: identity.title)
        }
    }

    @ViewBuilder
    private var titleView: some View {
        if let draftTitle {
            TextField(
                "",
                text: Binding(
                    get: { draftTitle },
                    set: { self.draftTitle = $0 }
                )
            )
            .textFieldStyle(.plain)
            .cmuxFont(size: 13, weight: .semibold)
            .focused($isTitleFieldFocused)
            .onSubmit(commitTitleEdit)
            .onExitCommand { self.draftTitle = nil }
            // Clicking away is a commit, matching how Finder and the sidebar
            // treat an open rename field.
            .onChange(of: isTitleFieldFocused) { _, focused in
                if !focused { commitTitleEdit() }
            }
            .onAppear { isTitleFieldFocused = true }
        } else {
            Text(identity.title)
                .cmuxFont(size: 13, weight: .semibold)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(isTitleHovered ? 0.10 : 0))
                )
                .contentShape(Rectangle())
                // A tap on the title edits it without selecting the workspace:
                // selecting would make the card's terminal reassert first
                // responder and pull the caret straight back out of this field.
                .onTapGesture {
                    // The title sits inside the header, so it has to honour the same
                    // modifiers; otherwise Shift-clicking a card's title would open
                    // the rename field instead of extending the selection.
                    let flags = NSEvent.modifierFlags
                    if flags.contains(.shift) || flags.contains(.command) {
                        onToggleMultiSelection()
                    } else {
                        beginTitleEdit()
                    }
                }
                .onHover { isTitleHovered = $0 }
                .help(String(
                    localized: "fleetCanvas.card.renameHint",
                    defaultValue: "Click to rename this workspace"
                ))
        }
    }

    private func beginTitleEdit() {
        draftTitle = workspace.customTitle ?? identity.title
        // The field takes focus in its own `onAppear`. When the edit starts from
        // the context menu, that happens while the menu is still tearing down and
        // AppKit hands focus back to the window afterwards, so the field is asked
        // again on the next turn of the main queue.
        isTitleFieldFocused = true
        DispatchQueue.main.async { isTitleFieldFocused = true }
    }

    private func commitTitleEdit() {
        guard let draftTitle else { return }
        self.draftTitle = nil
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        onRenameCommit(trimmed.isEmpty ? nil : trimmed)
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            if agentCount > 0 {
                Label(
                    String(localized: "fleetCanvas.card.agentCount", defaultValue: "\(agentCount) agents"),
                    systemImage: "person.2.fill"
                )
                .foregroundStyle(Color.secondary)
            }
            if runningAgentCount > 0 {
                Label(
                    String(localized: "fleetCanvas.card.running", defaultValue: "\(runningAgentCount) running"),
                    systemImage: "bolt.fill"
                )
                .foregroundStyle(FleetCanvasTheme.runningAgent)
            }
            if needsInputAgentCount > 0 {
                Label(
                    String(
                        localized: "fleetCanvas.card.needsInput",
                        defaultValue: "\(needsInputAgentCount) needs input"
                    ),
                    systemImage: "exclamationmark.circle.fill"
                )
                .foregroundStyle(FleetCanvasTheme.needsInputAgent)
            }
            if completedAgentCount > 0 {
                Label(
                    String(localized: "fleetCanvas.card.done", defaultValue: "\(completedAgentCount) done"),
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(FleetCanvasTheme.completedAgent)
            }
            Spacer(minLength: 4)
        }
        .cmuxFont(size: 10, weight: .medium)
    }

    private var cardBackgroundColor: Color {
        Color(nsColor: appearance.terminalBackgroundColor)
            .opacity(FleetCanvasTheme.cardBackgroundOpacity)
    }

    private static func alignment(for edge: FleetCanvasLayoutEdge) -> Alignment {
        switch edge {
        case .leading: .leading
        case .trailing: .trailing
        case .top: .top
        case .bottom: .bottom
        }
    }

    private var headerBackgroundColor: Color {
        // A card's header has to read as chrome over its own terminal fill, so
        // it lifts off the card background instead of adding another material.
        Color.white.opacity(isSelected ? 0.10 : 0.06)
    }
}
