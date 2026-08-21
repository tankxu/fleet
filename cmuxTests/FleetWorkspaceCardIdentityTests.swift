import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas card identity")
struct FleetWorkspaceCardIdentityTests {
    private let claude = FleetWorkspaceAgentPresence(
        agentId: "claude",
        displayName: "Claude Code",
        iconAssetName: "AgentIcons/Claude"
    )
    private let codex = FleetWorkspaceAgentPresence(
        agentId: "codex",
        displayName: "Codex",
        iconAssetName: "AgentIcons/Codex"
    )

    private func shell(_ directory: String?, title: String = "zsh") -> FleetWorkspacePanelSnapshot {
        FleetWorkspacePanelSnapshot(title: title, directory: directory, agent: nil)
    }

    private func agentPanel(
        _ agent: FleetWorkspaceAgentPresence,
        directory: String?,
        title: String
    ) -> FleetWorkspacePanelSnapshot {
        FleetWorkspacePanelSnapshot(title: title, directory: directory, agent: agent)
    }

    private func resolve(
        _ panels: [FleetWorkspacePanelSnapshot],
        workspaceTitle: String = "Terminal",
        workspaceDirectory: String? = nil
    ) -> FleetWorkspaceCardIdentity {
        FleetWorkspaceCardIdentity.resolve(
            panels: panels,
            workspaceTitle: workspaceTitle,
            workspaceDirectory: workspaceDirectory
        )
    }

    private var home: String { NSHomeDirectory() }

    @Test("A lone shell shows its path, tilde-abbreviated")
    func loneShellShowsPath() {
        let identity = resolve([shell("\(home)/LocalDev/cmux")])

        #expect(identity.title == "~/LocalDev/cmux")
        #expect(identity.icon == .terminal)
    }

    @Test("A lone shell with no directory falls back to the workspace title")
    func loneShellWithoutDirectory() {
        #expect(resolve([shell(nil)], workspaceTitle: "Scratch").title == "Scratch")
    }

    @Test("A lone agent shows agent and session title, with the agent's icon")
    func loneAgentShowsSession() {
        let identity = resolve([
            agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "fixing the drop indicator")
        ])

        #expect(identity.title == "Claude Code  ·  fixing the drop indicator")
        #expect(identity.icon == .agent(assetName: "AgentIcons/Claude"))
    }

    @Test("A session title that only repeats the agent name collapses to the name")
    func redundantSessionTitleCollapses() {
        #expect(resolve([agentPanel(claude, directory: home, title: "claude")]).title == "Claude Code")
        #expect(resolve([agentPanel(codex, directory: home, title: "Codex")]).title == "Codex")
    }

    @Test("One agent beside plain shells still names the session")
    func singleAgentAmongShellsNamesSession() {
        let identity = resolve([
            shell("\(home)/LocalDev/cmux"),
            agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "reviewing the diff"),
            shell("\(home)/LocalDev/cmux"),
        ])

        #expect(identity.title == "Claude Code  ·  reviewing the diff")
    }

    @Test("Several shells that agree on a directory show that directory")
    func agreeingShellsShowDirectory() {
        let identity = resolve([
            shell("\(home)/LocalDev/cmux"),
            shell("\(home)/LocalDev/cmux"),
        ])

        #expect(identity.title == "~/LocalDev/cmux")
        #expect(identity.icon == .terminal)
    }

    @Test("Several agents in one directory show the directory, not a session")
    func multipleAgentsShowDirectory() {
        let identity = resolve([
            agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "one"),
            agentPanel(codex, directory: "\(home)/LocalDev/cmux", title: "two"),
        ])

        #expect(identity.title == "~/LocalDev/cmux")
        #expect(identity.icon == .multipleAgents)
    }

    @Test("Agents of the same kind keep that kind's icon")
    func sameKindAgentsKeepIcon() {
        let identity = resolve([
            agentPanel(claude, directory: "\(home)/a", title: "one"),
            agentPanel(claude, directory: "\(home)/a", title: "two"),
        ])

        #expect(identity.icon == .agent(assetName: "AgentIcons/Claude"))
    }

    @Test("Panels in sibling directories show the tree they share, marked as collapsed")
    func siblingDirectoriesShowSharedTree() {
        let identity = resolve([
            agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "one"),
            agentPanel(codex, directory: "\(home)/LocalDev/web", title: "two"),
        ])

        #expect(identity.title == "~/LocalDev/…")
    }

    @Test("Panels sharing only the home directory fall back to the workspace title")
    func homeOnlyAncestorFallsBack() {
        let identity = resolve(
            [
                agentPanel(claude, directory: "\(home)/LocalDev", title: "one"),
                agentPanel(codex, directory: "\(home)/Documents", title: "two"),
            ],
            workspaceTitle: "Mixed bag"
        )

        #expect(identity.title == "Mixed bag")
    }

    @Test("Panels sharing only the filesystem root fall back to the workspace title")
    func rootOnlyAncestorFallsBack() {
        let identity = resolve(
            [
                agentPanel(claude, directory: "/opt/one", title: "one"),
                agentPanel(codex, directory: "/var/two", title: "two"),
            ],
            workspaceTitle: "Scattered"
        )

        #expect(identity.title == "Scattered")
    }

    @Test("An empty workspace falls back to its title")
    func emptyWorkspaceFallsBack() {
        #expect(resolve([], workspaceTitle: "Empty").title == "Empty")
        #expect(resolve([], workspaceTitle: "   ").title == FleetWorkspaceCardIdentity.untitledWorkspaceTitle)
    }

    @Test("A user-typed name outranks every derived title")
    func customTitleWins() {
        let panels = [
            agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "reviewing the diff"),
            shell("\(home)/LocalDev/web"),
        ]

        let identity = FleetWorkspaceCardIdentity.resolve(
            panels: panels,
            workspaceTitle: "Terminal",
            workspaceDirectory: home,
            customTitle: "Release prep"
        )

        #expect(identity.title == "Release prep")
        // The icon still reports what runs inside, so renaming does not hide it.
        #expect(identity.icon == .agent(assetName: "AgentIcons/Claude"))
    }

    @Test("A blank custom title does not shadow the derived title")
    func blankCustomTitleIgnored() {
        let identity = FleetWorkspaceCardIdentity.resolve(
            panels: [shell("\(home)/LocalDev/cmux")],
            workspaceTitle: "Terminal",
            customTitle: "   "
        )

        #expect(identity.title == "~/LocalDev/cmux")
    }

    @Test("A custom title survives an agent starting or finishing")
    func customTitleSurvivesAgentChurn() {
        let before = FleetWorkspaceCardIdentity.resolve(
            panels: [shell("\(home)/LocalDev/cmux")],
            workspaceTitle: "Terminal",
            customTitle: "Release prep"
        )
        let after = FleetWorkspaceCardIdentity.resolve(
            panels: [agentPanel(claude, directory: "\(home)/LocalDev/cmux", title: "working")],
            workspaceTitle: "Terminal",
            customTitle: "Release prep"
        )

        #expect(before.title == after.title)
    }

    @Test("A workspace-level directory covers a panel that reports none")
    func workspaceDirectoryCoversPanel() {
        let identity = resolve(
            [shell(nil)],
            workspaceTitle: "Terminal",
            workspaceDirectory: "\(home)/LocalDev/cmux"
        )

        #expect(identity.title == "~/LocalDev/cmux")
    }
}
