import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas agent catalog")
struct FleetWorkspaceAgentCatalogTests {
    @Test("Restored-session identifiers resolve to catalog entries")
    func restoredIdentifiersResolve() throws {
        let claude = try #require(FleetWorkspaceAgentCatalog.presence(forIdentifier: RestorableAgentKind.claude.rawValue))
        #expect(claude.agentId == "claude")
        #expect(claude.displayName == "Claude Code")
        #expect(claude.iconAssetName == "AgentIcons/Claude")

        let hermes = try #require(
            FleetWorkspaceAgentCatalog.presence(forIdentifier: RestorableAgentKind.hermesAgent.rawValue)
        )
        #expect(hermes.agentId == "hermes-agent")
    }

    @Test("Live hook lifecycle keys resolve to the same entries")
    func lifecycleKeysResolve() throws {
        let live = try #require(FleetWorkspaceAgentCatalog.presence(forIdentifier: "claude_code"))
        let restored = try #require(FleetWorkspaceAgentCatalog.presence(forIdentifier: "claude"))

        #expect(live == restored)
    }

    @Test("Every allowed lifecycle status key resolves")
    func allLifecycleKeysResolve() {
        for key in AgentHibernationLifecycleStatusKeys.allowedStatusKeys {
            #expect(FleetWorkspaceAgentCatalog.presence(forIdentifier: key) != nil, "unresolved key: \(key)")
        }
    }

    @Test("Reserved loading keys are not agents")
    func manualKeysAreNotAgents() {
        #expect(FleetWorkspaceAgentCatalog.presence(forIdentifier: "manual") == nil)
        #expect(FleetWorkspaceAgentCatalog.presence(forIdentifier: "manual:import") == nil)
        #expect(FleetWorkspaceAgentCatalog.presence(forIdentifier: "") == nil)
        #expect(FleetWorkspaceAgentCatalog.presence(forIdentifier: "not-an-agent") == nil)
    }
}
