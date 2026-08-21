import SwiftUI

/// Drag image for a fleet-canvas card.
///
/// A card's real body hosts an AppKit-backed terminal that does not render into
/// a SwiftUI drag snapshot, so a dragged card would otherwise fly as an empty
/// rectangle. This pill carries the card's identity instead.
struct FleetCanvasCardDragPreview: View {
    let title: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "square.grid.2x2.fill")
                .foregroundStyle(FleetCanvasTheme.accent)
            Text(title)
                .cmuxFont(size: 12, weight: .semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().stroke(FleetCanvasTheme.accent.opacity(0.6), lineWidth: 1))
    }
}
