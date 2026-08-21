import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Terminal surface focus policy")
struct TerminalSurfaceFocusPolicyTests {
    @Test("An inactive pane that owns no responder gives up its focus intent")
    func inactivePaneClearsIntent() {
        #expect(TerminalSurfaceFocusPolicy.shouldClearFocusIntent(
            isPaneActive: false,
            ownsFirstResponder: false
        ))
    }

    @Test("An active pane keeps its focus intent")
    func activePaneKeepsIntent() {
        #expect(!TerminalSurfaceFocusPolicy.shouldClearFocusIntent(
            isPaneActive: true,
            ownsFirstResponder: false
        ))
        #expect(!TerminalSurfaceFocusPolicy.shouldClearFocusIntent(
            isPaneActive: true,
            ownsFirstResponder: true
        ))
    }

    @Test("A pane still holding the responder chain keeps its focus intent")
    func responderOwnerKeepsIntent() {
        // AppKit's own resign path owns this transition; clearing here as well
        // would race it and can drop focus from the pane the user is typing in.
        #expect(!TerminalSurfaceFocusPolicy.shouldClearFocusIntent(
            isPaneActive: false,
            ownsFirstResponder: true
        ))
    }
}
