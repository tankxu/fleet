import CoreGraphics
import Foundation

/// Converts a divider drag into new container weights.
///
/// Only the two members the divider sits between change; everything else in the
/// container keeps the size the user gave it. That is what makes dragging one
/// divider feel local instead of reflowing the whole board.
enum FleetCanvasLayoutWeightDrag {
    /// Weights after dragging the divider following `leadingIndex` by `delta`
    /// points, or `nil` when the drag cannot apply.
    ///
    /// Returning `nil` rather than the input matters: the input is already
    /// normalized, so handing it back would rewrite an untouched container's
    /// weights and make a no-op drag look like a deliberate layout.
    static func adjusted(
        fractions: [CGFloat],
        leadingIndex: Int,
        delta: CGFloat,
        usableLength: CGFloat,
        minimumFraction: CGFloat = FleetCanvasLayoutNode.minimumWeightFraction
    ) -> [CGFloat]? {
        guard fractions.indices.contains(leadingIndex),
              fractions.indices.contains(leadingIndex + 1),
              usableLength > 0,
              delta.isFinite else {
            return nil
        }
        let leading = fractions[leadingIndex]
        let trailing = fractions[leadingIndex + 1]
        let pairTotal = leading + trailing
        let lowerBound = min(minimumFraction, pairTotal / 2)
        let upperBound = pairTotal - lowerBound
        let proposed = leading + delta / usableLength
        let clamped = min(max(proposed, lowerBound), upperBound)
        var adjusted = fractions
        adjusted[leadingIndex] = clamped
        adjusted[leadingIndex + 1] = pairTotal - clamped
        return adjusted
    }
}
