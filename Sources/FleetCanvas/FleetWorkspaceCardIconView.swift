import SwiftUI

/// Draws a card's agent icon, falling back to an SF Symbol when the agent ships
/// no bundled asset (or when the workspace runs plain shells).
struct FleetWorkspaceCardIconView: View {
    let icon: FleetWorkspaceCardIcon
    let isSelected: Bool

    private static let side: CGFloat = 13

    var body: some View {
        if case let .agent(assetName) = icon, let assetName, NSImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.side, height: Self.side)
                // Agent marks are full-color logos, so they keep their own color
                // rather than taking the card's selection tint.
                .opacity(isSelected ? 1 : 0.75)
        } else {
            Image(systemName: icon.fallbackSymbolName)
                .foregroundStyle(isSelected ? FleetCanvasTheme.accent : Color.secondary)
        }
    }
}
