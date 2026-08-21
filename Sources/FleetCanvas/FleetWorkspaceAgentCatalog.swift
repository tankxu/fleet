import Foundation

/// Resolves the agent identifiers cmux records on a panel into presentable
/// names and icons.
///
/// Two identifier vocabularies reach the board: `RestorableAgentKind.rawValue`
/// (`claude`, `hermes-agent`) from restored sessions, and hook lifecycle keys
/// (`claude_code`) from live ones. Both are matched against the same agent
/// catalog so a card cannot label a live Claude differently from a restored one.
enum FleetWorkspaceAgentCatalog {
    /// Presentation for an agent identifier, or `nil` when it names no known
    /// agent (including the reserved `manual` loading keys).
    static func presence(forIdentifier identifier: String) -> FleetWorkspaceAgentPresence? {
        let normalized = normalize(identifier)
        guard !normalized.isEmpty, !AgentHibernationLifecycleStatusKeys.isManualKey(identifier) else {
            return nil
        }
        guard let definition = definition(forNormalizedIdentifier: normalized) else { return nil }
        return FleetWorkspaceAgentPresence(
            agentId: definition.id,
            displayName: definition.displayName,
            iconAssetName: definition.assetName
        )
    }

    private static func definition(
        forNormalizedIdentifier normalized: String
    ) -> CmuxTaskManagerCodingAgentDefinition? {
        let definitions = CmuxTaskManagerCodingAgentDefinition.builtIns
        if let exact = definitions.first(where: { normalize($0.id) == normalized }) {
            return exact
        }
        if let byLaunchKind = definitions.first(where: {
            $0.launchKinds.contains { normalize($0) == normalized }
        }) {
            return byLaunchKind
        }
        // `claude_code` has to reach the `claude` definition. Prefix matching is
        // bounded to catalog ids of three or more characters so a short id such
        // as `pi` cannot claim an unrelated key.
        return definitions
            .filter { normalize($0.id).count >= 3 && normalized.hasPrefix(normalize($0.id)) }
            .max { normalize($0.id).count < normalize($1.id).count }
    }

    private static func normalize(_ identifier: String) -> String {
        identifier.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
