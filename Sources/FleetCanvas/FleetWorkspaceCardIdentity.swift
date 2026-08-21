import Foundation

/// Title and glyph for one fleet-canvas card.
///
/// A board is only scannable if each card answers "what is this?" in one line,
/// and the useful answer changes with what the workspace holds: a lone shell is
/// its directory, a lone agent is its session, and a workspace full of both is
/// the place they share. The resolver encodes that ladder so the card view has
/// no branching of its own.
///
/// A user-typed name short-circuits the whole ladder: once someone renames a
/// card, no amount of agent or directory churn may relabel it.
struct FleetWorkspaceCardIdentity: Equatable {
    let title: String
    let icon: FleetWorkspaceCardIcon

    /// Resolves the identity for a workspace's panels.
    ///
    /// - Parameters:
    ///   - panels: Panels in tab order.
    ///   - workspaceTitle: Fallback when no directory or session describes the
    ///     workspace better.
    ///   - workspaceDirectory: Workspace-level directory, used when a panel does
    ///     not report one of its own.
    static func resolve(
        panels: [FleetWorkspacePanelSnapshot],
        workspaceTitle: String,
        workspaceDirectory: String? = nil,
        customTitle: String? = nil
    ) -> FleetWorkspaceCardIdentity {
        let fallbackTitle = trimmed(workspaceTitle) ?? untitledWorkspaceTitle
        let agents = panels.compactMap(\.agent)
        let icon = resolveIcon(agents: agents)

        // A name the user typed outranks everything derived. The icon still
        // tracks what is actually running, so renaming a card does not hide
        // which agent owns it.
        if let customTitle = trimmed(customTitle) {
            return FleetWorkspaceCardIdentity(title: customTitle, icon: icon)
        }
        let directories = panels.compactMap { trimmed($0.directory) }
        let uniqueDirectories = Set(directories)

        // A single agent describes the workspace better than its path, whether
        // it sits alone or beside plain shells.
        if agents.count == 1,
           let panel = panels.first(where: { $0.agent != nil }),
           let agent = panel.agent {
            return FleetWorkspaceCardIdentity(
                title: sessionTitle(agent: agent, panelTitle: panel.title),
                icon: icon
            )
        }

        // No agent, one panel: the path is the whole story.
        if agents.isEmpty, panels.count <= 1 {
            let directory = directories.first ?? trimmed(workspaceDirectory)
            return FleetWorkspaceCardIdentity(
                title: directory.map(displayPath) ?? fallbackTitle,
                icon: icon
            )
        }

        // Several panels (or several agents) that agree on where they are.
        if uniqueDirectories.count == 1, let directory = uniqueDirectories.first {
            return FleetWorkspaceCardIdentity(title: displayPath(directory), icon: icon)
        }

        // Panels scattered across sibling directories: name the tree they share
        // and mark it as a collapsed prefix, which still tells you which project
        // this card belongs to.
        if uniqueDirectories.count > 1,
           let shared = commonAncestor(of: uniqueDirectories) {
            return FleetWorkspaceCardIdentity(title: "\(displayPath(shared))/…", icon: icon)
        }

        // Nothing shared and no single session: fall back to the workspace's own
        // name, which the user can rename.
        return FleetWorkspaceCardIdentity(title: fallbackTitle, icon: icon)
    }

    /// Shown when a workspace has neither a name, a directory, nor a session.
    static var untitledWorkspaceTitle: String {
        String(localized: "fleetCanvas.card.untitledWorkspace", defaultValue: "Workspace")
    }

    private static func resolveIcon(agents: [FleetWorkspaceAgentPresence]) -> FleetWorkspaceCardIcon {
        let uniqueIds = Set(agents.map(\.agentId))
        if uniqueIds.count > 1 { return .multipleAgents }
        if let agent = agents.first { return .agent(assetName: agent.iconAssetName) }
        return .terminal
    }

    /// `Claude Code · fixing the drop indicator`, collapsing to just the agent
    /// name when the panel title carries no more information than the name does.
    private static func sessionTitle(
        agent: FleetWorkspaceAgentPresence,
        panelTitle: String
    ) -> String {
        guard let title = trimmed(panelTitle).map(FleetWorkspaceSessionTitle.sanitized),
              !title.isEmpty else { return agent.displayName }
        let comparableTitle = comparable(title)
        guard !comparableTitle.isEmpty,
              comparableTitle != comparable(agent.displayName),
              comparableTitle != comparable(agent.agentId) else {
            return agent.displayName
        }
        return "\(agent.displayName)  ·  \(title)"
    }

    /// Deepest directory every path shares, or `nil` when the only shared
    /// ancestor is the home directory or the filesystem root — neither of which
    /// identifies anything.
    private static func commonAncestor(of directories: Set<String>) -> String? {
        guard directories.count > 1 else { return directories.first }
        let components = directories.map { standardized($0).split(separator: "/").map(String.init) }
        guard let first = components.first else { return nil }
        var shared: [String] = []
        for (index, component) in first.enumerated() {
            guard components.allSatisfy({ index < $0.count && $0[index] == component }) else { break }
            shared.append(component)
        }
        guard !shared.isEmpty else { return nil }
        let path = "/" + shared.joined(separator: "/")
        let abbreviated = displayPath(path)
        guard abbreviated != "~", abbreviated != "/" else { return nil }
        return path
    }

    private static func displayPath(_ path: String) -> String {
        (standardized(path) as NSString).abbreviatingWithTildeInPath
    }

    private static func standardized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private static func comparable(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
