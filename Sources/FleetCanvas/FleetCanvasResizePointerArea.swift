import AppKit
import SwiftUI

/// AppKit pointer handling for a board divider: cursor, hover position, and drag.
///
/// All of it lives in AppKit rather than SwiftUI because of the cursor. The
/// terminals on both sides of a divider set an I-beam from their own tracking
/// areas on every pointer move, and neither `NSCursor.push()` from a SwiftUI
/// hover callback nor a cursor rect on a hit-test-transparent view survives that:
/// the first is overwritten on the next move, the second is skipped because
/// AppKit ignores views that decline hit testing when it picks a cursor. A
/// tracking area that answers `cursorUpdate` is re-consulted every time the
/// pointer enters, which is the one mechanism that wins.
///
/// Since this view must accept hit testing for the cursor to work, it also owns
/// the drag — a SwiftUI gesture underneath would never see the events.
struct FleetCanvasResizePointerArea: NSViewRepresentable {
    let axis: FleetCanvasResizeAxis
    /// Pointer position along the divider, or `nil` once the pointer leaves.
    let onPointerOffset: (CGFloat?) -> Void
    let onDrag: (CGFloat) -> Void
    let onCommit: (CGFloat) -> Void
    let onReset: () -> Void

    func makeNSView(context: Context) -> PointerAreaView {
        PointerAreaView(axis: axis)
    }

    func updateNSView(_ nsView: PointerAreaView, context: Context) {
        nsView.axis = axis
        nsView.onPointerOffset = onPointerOffset
        nsView.onDrag = onDrag
        nsView.onCommit = onCommit
        nsView.onReset = onReset
    }

    final class PointerAreaView: NSView {
        var axis: FleetCanvasResizeAxis
        var onPointerOffset: ((CGFloat?) -> Void)?
        var onDrag: ((CGFloat) -> Void)?
        var onCommit: ((CGFloat) -> Void)?
        var onReset: (() -> Void)?

        private var trackingArea: NSTrackingArea?
        private var dragOrigin: NSPoint?

        /// Flipped so pointer offsets share SwiftUI's downward y axis and can be
        /// handed straight to the indicator.
        override var isFlipped: Bool { true }

        init(axis: FleetCanvasResizeAxis) {
            self.axis = axis
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let trackingArea {
                removeTrackingArea(trackingArea)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeInActiveApp],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func cursorUpdate(with event: NSEvent) {
            axis.cursor.set()
        }

        override func mouseEntered(with event: NSEvent) {
            reportOffset(for: event)
        }

        override func mouseMoved(with event: NSEvent) {
            reportOffset(for: event)
        }

        override func mouseExited(with event: NSEvent) {
            guard dragOrigin == nil else { return }
            onPointerOffset?(nil)
        }

        override func mouseDown(with event: NSEvent) {
            if event.clickCount == 2 {
                onReset?()
                return
            }
            dragOrigin = event.locationInWindow
            axis.cursor.set()
        }

        override func mouseDragged(with event: NSEvent) {
            guard let dragOrigin else { return }
            // Window coordinates: the board re-lays out mid-drag, which moves this
            // view. Measuring against the window keeps the drag pinned to the
            // pointer instead of drifting with the handle.
            onDrag?(delta(from: dragOrigin, to: event.locationInWindow))
            axis.cursor.set()
        }

        override func mouseUp(with event: NSEvent) {
            guard let dragOrigin else { return }
            self.dragOrigin = nil
            onCommit?(delta(from: dragOrigin, to: event.locationInWindow))
        }

        private func delta(from origin: NSPoint, to current: NSPoint) -> CGFloat {
            switch axis {
            case .columns:
                return current.x - origin.x
            case .rows:
                // Window y grows upward while rows are laid out downward, so
                // dragging down must grow the row above the divider.
                return origin.y - current.y
            }
        }

        private func reportOffset(for event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            onPointerOffset?(axis == .columns ? point.y : point.x)
        }
    }
}
