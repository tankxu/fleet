import Foundation
import QuartzCore
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Workspace attention ring pulse")
struct WorkspaceAttentionRingPulseTests {
    private let pulse = WorkspaceAttentionRingPulse.standard

    @Test("The pulse dims without going invisible")
    func pulseStaysVisible() {
        #expect(pulse.minimumOpacity > 0)
        #expect(pulse.minimumOpacity < pulse.maximumOpacity)
        #expect(pulse.maximumOpacity == 1)
    }

    @Test("A half cycle is half the period, so dim-and-return spans one period")
    func halfCycleIsHalfPeriod() {
        #expect(pulse.halfCycleDuration == pulse.period / 2)
    }

    @Test("Rings raised at different moments in one cycle share a phase")
    func beginTimesAlignToSharedPhase() {
        // Both moments must sit inside the same cycle; two timestamps straddling a
        // boundary belong to different cycles by design, which is what keeps the
        // phase grid stable rather than drifting with whoever raised a ring last.
        let boundary = pulse.period * 62
        let first = pulse.alignedBeginTime(now: boundary + 0.01)
        let second = pulse.alignedBeginTime(now: boundary + pulse.period * 0.95)

        #expect(abs(first - second) < 0.000_001)
        #expect(abs(first - boundary) < 0.000_001)
    }

    @Test("Consecutive periods align to consecutive boundaries")
    func consecutivePeriodsAlign() {
        let early = pulse.alignedBeginTime(now: 100.0)
        let later = pulse.alignedBeginTime(now: 100.0 + pulse.period)

        #expect(abs((later - early) - pulse.period) < 0.000_001)
    }

    @Test("An aligned begin time never runs ahead of now")
    func alignedBeginTimeIsNotInTheFuture() {
        for now in [0.0, 0.5, 1.6, 12.34, 987.65] {
            #expect(pulse.alignedBeginTime(now: now) <= now)
        }
    }

    @Test("A degenerate period falls back to the current time instead of dividing by zero")
    func zeroPeriodFallsBack() {
        let degenerate = WorkspaceAttentionRingPulse(period: 0, minimumOpacity: 0.5, maximumOpacity: 1)

        #expect(degenerate.alignedBeginTime(now: 42) == 42)
    }
}
