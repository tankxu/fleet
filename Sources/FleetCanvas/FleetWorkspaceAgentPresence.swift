/// A coding agent observed on one workspace panel.
struct FleetWorkspaceAgentPresence: Equatable {
    /// Catalog id, e.g. `claude`.
    let agentId: String

    /// Human-facing name, e.g. `Claude Code`.
    let displayName: String

    /// Asset-catalog path for the agent's icon, when one is bundled.
    let iconAssetName: String?
}
