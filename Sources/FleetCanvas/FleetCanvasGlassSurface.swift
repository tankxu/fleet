import SwiftUI

/// Glass background for a fleet-canvas surface.
///
/// Uses the real macOS 26 liquid glass (`glassEffect`) rather than a
/// window-blended `NSVisualEffectView`, because native glass refracts what is
/// locally behind the surface instead of tinting from a wide desktop sample —
/// the difference between "translucent" and "the whole window went yellow".
struct FleetCanvasGlassSurface: View {
    let depth: FleetCanvasGlassDepth
    var cornerRadius: CGFloat = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
#if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            shape
                .fill(Color.clear)
                .glassEffect(.regular.tint(depth.tint), in: shape)
        } else {
            fallback(shape)
        }
#else
        fallback(shape)
#endif
    }

    @ViewBuilder
    private func fallback(_ shape: RoundedRectangle) -> some View {
        FleetCanvasVisualEffectBackground(
            material: depth.fallbackMaterial,
            cornerRadius: cornerRadius
        )
        .overlay(shape.fill(depth.tint))
        .clipShape(shape)
    }
}
