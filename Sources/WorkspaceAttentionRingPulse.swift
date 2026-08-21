import QuartzCore

/// Breathing animation applied to an unread-notification ring.
///
/// A steady ring competes with everything else on screen and loses; motion is
/// what a peripheral-vision cue needs. It is a smooth pulse rather than a hard
/// blink because the ring sits directly beside terminal text a user is reading,
/// and a square-wave blink there is closer to an alarm than a hint.
struct WorkspaceAttentionRingPulse: Equatable {
    /// Seconds for one full dim-and-return cycle.
    let period: CFTimeInterval

    /// Opacity at the dimmest point of the cycle.
    let minimumOpacity: Float

    /// Opacity at the brightest point of the cycle.
    let maximumOpacity: Float

    static let standard = WorkspaceAttentionRingPulse(
        period: 1.6,
        minimumOpacity: 0.35,
        maximumOpacity: 1
    )

    /// Half a cycle: the animation dims over this duration, then autoreverses.
    var halfCycleDuration: CFTimeInterval { period / 2 }

    /// Start time snapped back to the previous period boundary.
    ///
    /// Rings are added whenever an agent happens to finish, so without a shared
    /// time base a board of waiting workspaces would breathe out of phase and
    /// read as flicker instead of one signal.
    func alignedBeginTime(now: CFTimeInterval) -> CFTimeInterval {
        guard period > 0 else { return now }
        return (now / period).rounded(.down) * period
    }
}
