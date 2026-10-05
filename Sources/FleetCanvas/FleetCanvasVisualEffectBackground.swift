import AppKit
import SwiftUI

/// `NSVisualEffectView` backing used when native macOS 26 glass is unavailable.
struct FleetCanvasVisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let colorScheme: ColorScheme
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layerContentsRedrawPolicy = .onSetNeedsDisplay
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        // Pinned so the material renders in the terminal theme's scheme, not
        // whatever the system appearance happens to be.
        nsView.appearance = NSAppearance(named: colorScheme == .light ? .aqua : .darkAqua)
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = cornerRadius > 0
    }
}
