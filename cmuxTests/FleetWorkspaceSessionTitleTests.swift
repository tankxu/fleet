import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas session titles")
struct FleetWorkspaceSessionTitleTests {
    @Test("An agent's spinner glyph is stripped")
    func spinnerGlyphStripped() {
        #expect(FleetWorkspaceSessionTitle.sanitized("✻ sticks3 音乐播放问题") == "sticks3 音乐播放问题")
        #expect(FleetWorkspaceSessionTitle.sanitized("✳ Doing work") == "Doing work")
        #expect(FleetWorkspaceSessionTitle.sanitized("* 3 files changed") == "3 files changed")
    }

    @Test("Braille spinners are stripped")
    func brailleSpinnerStripped() {
        #expect(FleetWorkspaceSessionTitle.sanitized("⠹ building") == "building")
        #expect(FleetWorkspaceSessionTitle.sanitized("⠏ linting") == "linting")
    }

    @Test("Trailing ornaments are stripped too")
    func trailingOrnamentsStripped() {
        #expect(FleetWorkspaceSessionTitle.sanitized("running tests ✻") == "running tests")
    }

    @Test("Characters that can start a real title survive")
    func meaningfulPrefixesSurvive() {
        #expect(FleetWorkspaceSessionTitle.sanitized("/review changes") == "/review changes")
        #expect(FleetWorkspaceSessionTitle.sanitized("#4529 repro") == "#4529 repro")
        #expect(FleetWorkspaceSessionTitle.sanitized("~/LocalDev/cmux") == "~/LocalDev/cmux")
        #expect(FleetWorkspaceSessionTitle.sanitized("...continuing") == "...continuing")
    }

    @Test("A title made only of ornaments keeps its text")
    func ornamentOnlyTitleSurvives() {
        #expect(FleetWorkspaceSessionTitle.sanitized("✻") == "✻")
        #expect(FleetWorkspaceSessionTitle.sanitized("  ✻ ⠹  ") == "✻ ⠹")
    }

    @Test("Ordinary titles are only whitespace-trimmed")
    func ordinaryTitlesUnchanged() {
        #expect(FleetWorkspaceSessionTitle.sanitized("  fixing the drop indicator  ") == "fixing the drop indicator")
        #expect(FleetWorkspaceSessionTitle.sanitized("zsh") == "zsh")
    }
}
