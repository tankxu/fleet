/// Immutable view of one workspace panel, as the card title resolver sees it.
struct FleetWorkspacePanelSnapshot: Equatable {
    /// Resolved panel title. For an agent panel this is the session's own
    /// terminal title, which is what the agent writes as it works.
    let title: String

    /// The panel's working directory, when it reports one.
    let directory: String?

    /// The coding agent running in the panel, when there is one.
    let agent: FleetWorkspaceAgentPresence?
}
