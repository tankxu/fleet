import AppKit
import SwiftUI

/// How transparent one fleet-canvas glass surface should be.
///
/// Only the board itself and the right sidebar are glass. Workspace cards stay
/// close to opaque on purpose: glass stacked on glass turns milky and costs the
/// terminal its contrast, and the card-vs-board separation the board depends on
/// comes precisely from cards *not* being see-through.
enum FleetCanvasGlassDepth {
    /// The board behind the cards — the most transparent surface in the window.
    case canvas

    /// The right sidebar — slightly see-through, still readable as chrome.
    case sidebar

    var tint: Color {
        switch self {
        case .canvas: FleetCanvasTheme.canvasGlassTint
        case .sidebar: FleetCanvasTheme.sidebarGlassTint
        }
    }

    /// Fallback material for pre-macOS 26 systems.
    ///
    /// Never `.underWindowBackground`: that material is meant for the shadow
    /// region *below* a window and, blended behind the window, samples far
    /// enough across the desktop that a saturated wallpaper bleeds its hue over
    /// the whole canvas even when nothing colorful sits behind the window.
    var fallbackMaterial: NSVisualEffectView.Material {
        switch self {
        case .canvas: .hudWindow
        case .sidebar: .sidebar
        }
    }
}
