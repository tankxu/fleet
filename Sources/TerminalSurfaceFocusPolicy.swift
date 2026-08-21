/// When a terminal pane must give up its Ghostty keyboard-focus intent.
///
/// Ghostty paints a solid blinking cursor only while a surface holds focus, and
/// a surface adopts whatever focus intent it was created with. A pane that never
/// owned the AppKit responder chain therefore never ran the resign path that
/// clears a stale intent — invisible while only one workspace is mounted, but on
/// the fleet canvas, where every workspace renders at once, it shows up as every
/// card blinking a solid cursor together. Exactly one pane may blink; the rest
/// fall back to Ghostty's unfocused hollow block.
enum TerminalSurfaceFocusPolicy {
    /// Whether a pane going inactive should clear its focus intent.
    static func shouldClearFocusIntent(isPaneActive: Bool, ownsFirstResponder: Bool) -> Bool {
        !isPaneActive && !ownsFirstResponder
    }
}
