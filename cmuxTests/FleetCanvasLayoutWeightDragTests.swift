import CoreGraphics
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas divider drags")
struct FleetCanvasLayoutWeightDragTests {
    @Test("A drag moves space between two neighbours only")
    func dragMovesSpaceBetweenNeighbours() {
        let fractions: [CGFloat] = [1.0 / 3, 1.0 / 3, 1.0 / 3]
        guard let adjusted = FleetCanvasLayoutWeightDrag.adjusted(
            fractions: fractions,
            leadingIndex: 0,
            delta: 90,
            usableLength: 900
        ) else {
            Issue.record("expected adjusted weights for adjusted")
            return
        }

        #expect(abs(adjusted[0] - (1.0 / 3 + 0.1)) < 0.001)
        #expect(abs(adjusted[1] - (1.0 / 3 - 0.1)) < 0.001)
        // The untouched member keeps exactly what it had.
        #expect(abs(adjusted[2] - 1.0 / 3) < 0.000_001)
    }

    @Test("A drag is one-to-one with the pointer")
    func dragIsOneToOne() {
        guard let adjusted = FleetCanvasLayoutWeightDrag.adjusted(
            fractions: [0.5, 0.5],
            leadingIndex: 0,
            delta: 100,
            usableLength: 1000
        ) else {
            Issue.record("expected adjusted weights for adjusted")
            return
        }

        #expect(abs(adjusted[0] - 0.6) < 0.000_001)
    }

    @Test("A member cannot be collapsed below the minimum share")
    func dragClampsAtMinimum() {
        guard let grown = FleetCanvasLayoutWeightDrag.adjusted(
            fractions: [0.5, 0.5],
            leadingIndex: 0,
            delta: 10_000,
            usableLength: 900
        ) else {
            Issue.record("expected adjusted weights for grown")
            return
        }
        guard let shrunk = FleetCanvasLayoutWeightDrag.adjusted(
            fractions: [0.5, 0.5],
            leadingIndex: 0,
            delta: -10_000,
            usableLength: 900
        ) else {
            Issue.record("expected adjusted weights for shrunk")
            return
        }

        #expect(grown[1] >= FleetCanvasLayoutNode.minimumWeightFraction - 0.000_001)
        #expect(shrunk[0] >= FleetCanvasLayoutNode.minimumWeightFraction - 0.000_001)
        #expect(abs(grown.reduce(0, +) - 1) < 0.000_001)
    }

    @Test("An inapplicable drag reports no change rather than rewriting weights")
    func inapplicableDragReturnsNil() {
        let fractions: [CGFloat] = [0.5, 0.5]

        #expect(FleetCanvasLayoutWeightDrag.adjusted(fractions: fractions, leadingIndex: 1, delta: 40, usableLength: 900) == nil)
        #expect(FleetCanvasLayoutWeightDrag.adjusted(fractions: fractions, leadingIndex: 5, delta: 40, usableLength: 900) == nil)
        #expect(FleetCanvasLayoutWeightDrag.adjusted(fractions: fractions, leadingIndex: 0, delta: 40, usableLength: 0) == nil)
        #expect(FleetCanvasLayoutWeightDrag.adjusted(fractions: fractions, leadingIndex: 0, delta: .nan, usableLength: 900) == nil)
    }
}
