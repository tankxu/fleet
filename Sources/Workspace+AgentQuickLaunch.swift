import Bonsplit
import Foundation

extension Workspace {
    /// Runs `shellInput` in the pane's terminal when it is free, and in a new pane
    /// beside it when it is not.
    ///
    /// This is the behavior a one-click agent button needs. Typing into a terminal
    /// that is mid-command would corrupt whatever is running there, so a busy pane
    /// gets a sibling instead — inheriting the same working directory, which is the
    /// whole reason the button lives in the pane rather than on the board.
    ///
    /// An unknown activity state is treated as busy: cmux only knows a shell is
    /// idle once shell integration has reported a prompt, and guessing wrong in the
    /// other direction destroys work.
    func sendCommandPreferringIdleTerminal(_ shellInput: String, inPane pane: PaneID?) {
        let targetPane = pane ?? bonsplitController.focusedPaneId
        guard let targetPane else { return }
        let panel = selectedTerminalPanel(inPane: targetPane)

        if let panel, panelShellActivityStates[panel.id] == .promptIdle {
            panel.sendInput(shellInput)
            return
        }

        _ = splitPaneWithNewTerminal(
            targetPane: targetPane,
            orientation: .horizontal,
            insertFirst: false,
            workingDirectory: agentLaunchWorkingDirectory(forPanel: panel),
            initialInput: shellInput
        )
    }

    /// Directory a launched agent should start in: the pane's own, falling back to
    /// the workspace's.
    private func agentLaunchWorkingDirectory(forPanel panel: TerminalPanel?) -> String? {
        let candidates = [
            panel.flatMap { panelDirectories[$0.id] },
            panel?.requestedWorkingDirectory,
            currentDirectory,
        ]
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
