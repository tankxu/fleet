import AppKit

/// Which axis a board divider resizes.
enum FleetCanvasResizeAxis {
    case columns
    case rows

    var cursor: NSCursor {
        switch self {
        case .columns: .resizeLeftRight
        case .rows: .resizeUpDown
        }
    }
}
