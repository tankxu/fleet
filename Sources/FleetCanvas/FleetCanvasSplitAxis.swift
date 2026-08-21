/// Direction a layout group divides its two children.
enum FleetCanvasSplitAxis: String, Codable, Equatable {
    /// Children sit side by side; the divider is vertical.
    case horizontal
    /// Children stack; the divider is horizontal.
    case vertical
}
