import AppKit
import SwiftUI

/// Draggable divider between two board tracks.
///
/// The gap the grid reserves between cards is the divider's home, but the
/// grabbable area overhangs it into both cards: a divider you can only catch
/// inside a 16pt gap is a divider you keep missing. Nothing is drawn until the
/// pointer is in range — a board of live terminals should not be permanently
/// gridded with chrome.
struct FleetCanvasResizeHandle: View {
    let axis: FleetCanvasResizeAxis
    let thickness: CGFloat
    /// Height at the top of a card that the divider must not reach into.
    ///
    /// A vertical divider runs the full height of the cards beside it, which means
    /// its grab area would otherwise sit on top of each card's header and the
    /// pane's action buttons — swallowing clicks on the right-most icon and
    /// turning the pointer into a resize arrow over chrome that has nothing to do
    /// with resizing.
    var chromeInset: CGFloat = 0
    let onDrag: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void
    let onReset: () -> Void

    /// Full length of the drawn indicator, when the track is long enough.
    private static let indicatorLength: CGFloat = 120

    /// Thickness of the drawn indicator.
    private static let indicatorThickness: CGFloat = 3

    /// How far past the gap, into the cards on either side, the divider stays
    /// grabbable.
    ///
    /// Asymmetric on purpose. A vertical divider has a whole card edge to spare,
    /// so a generous reach makes it easy to catch. A horizontal one runs along the
    /// card's header and its bottom edge, where the same reach would swallow
    /// clicks meant for the header — 4pt is enough to make the divider catchable
    /// without shadowing anything.
    private static func grabExtension(for axis: FleetCanvasResizeAxis) -> CGFloat {
        switch axis {
        case .columns: 24
        case .rows: 4
        }
    }

    @State private var pointerOffset: CGFloat?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let inset = axis == .columns ? chromeInset : 0
            let trackLength = (axis == .columns ? proxy.size.height : proxy.size.width) - inset
            // A short indicator is a hint; one drawn edge to edge reads as
            // permanent structure and visually fences the terminals in.
            let length = min(Self.indicatorLength, max(24, trackLength * 0.6))
            Rectangle()
                .fill(Color.clear)
                .overlay(alignment: .center) {
                    if let pointerOffset {
                        indicator(length: length, offset: pointerOffset, trackLength: trackLength)
                    }
                }
                // The pointer area overhangs the gap on the cross axis. A SwiftUI
                // overlay may exceed its parent's frame and still take hits, while
                // widening the frame itself would change the grid's geometry.
                .overlay(alignment: axis == .columns ? .bottom : .center) {
                    FleetCanvasResizePointerArea(
                        axis: axis,
                        onPointerOffset: { offset in
                            guard !isDragging else { return }
                            pointerOffset = offset
                        },
                        onDrag: { delta in
                            isDragging = true
                            onDrag(delta)
                        },
                        onCommit: { delta in
                            isDragging = false
                            onCommit(delta)
                            // `pointerOffset` is deliberately kept: the pointer is
                            // usually still in range when a drag ends, and clearing
                            // it would blink the indicator out and back.
                        },
                        onReset: onReset
                    )
                    .frame(
                        width: axis == .columns ? thickness + Self.grabExtension(for: axis) * 2 : nil,
                        height: axis == .rows ? thickness + Self.grabExtension(for: axis) * 2 : nil
                    )
                    // Bottom-aligned and shortened, so the top of the track stays
                    // free for the cards' own chrome.
                    .frame(maxHeight: axis == .columns ? max(1, trackLength) : nil)
                }
        }
        .frame(
            width: axis == .columns ? thickness : nil,
            height: axis == .rows ? thickness : nil
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func indicator(length: CGFloat, offset: CGFloat, trackLength: CGFloat) -> some View {
        // Clamped so the indicator stays inside the track when the pointer nears
        // an end.
        let half = length / 2
        let inset = axis == .columns ? chromeInset : 0
        // `offset` is measured inside the pointer area, which starts below the
        // chrome inset, so the indicator is placed in the same space.
        let center = inset + min(max(offset, half), max(half, trackLength - half))
        Capsule()
            .fill(FleetCanvasTheme.accent.opacity(isDragging ? 0.95 : 0.7))
            .frame(
                width: axis == .columns ? Self.indicatorThickness : length,
                height: axis == .columns ? length : Self.indicatorThickness
            )
            .position(
                x: axis == .columns ? thickness / 2 : center,
                y: axis == .columns ? center : thickness / 2
            )
            .allowsHitTesting(false)
    }
}
