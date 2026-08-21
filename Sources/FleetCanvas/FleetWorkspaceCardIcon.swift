/// Glyph a fleet-canvas card shows for what is running inside it.
enum FleetWorkspaceCardIcon: Equatable {
    /// One agent (or several of the same kind) owns the workspace.
    case agent(assetName: String?)

    /// Several different agents share the workspace.
    case multipleAgents

    /// Plain shells, no agent.
    case terminal

    /// SF Symbol drawn when no bundled asset applies.
    var fallbackSymbolName: String {
        switch self {
        case .agent: "sparkles"
        case .multipleAgents: "square.grid.2x2.fill"
        case .terminal: "terminal"
        }
    }
}
