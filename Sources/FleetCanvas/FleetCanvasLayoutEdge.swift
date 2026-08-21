/// Which side of a card a dropped card lands on.
enum FleetCanvasLayoutEdge: String, Codable, Equatable, CaseIterable {
    case leading
    case trailing
    case top
    case bottom

    /// Axis of the group this drop creates.
    var axis: FleetCanvasSplitAxis {
        switch self {
        case .leading, .trailing: .horizontal
        case .top, .bottom: .vertical
        }
    }

    /// Whether the dropped card becomes the group's first child.
    var placesFirst: Bool {
        switch self {
        case .leading, .top: true
        case .trailing, .bottom: false
        }
    }
}
