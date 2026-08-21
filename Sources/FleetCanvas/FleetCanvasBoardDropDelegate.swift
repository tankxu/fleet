import SwiftUI

/// Single drop target covering the whole board.
///
/// Carries closures rather than the tab manager or the tree: the board owns both,
/// and this only needs to report where the pointer is and whether the drop landed.
struct FleetCanvasBoardDropDelegate: DropDelegate {
    let onLocationChange: (CGPoint?) -> Void
    let onPerformDrop: (CGPoint) -> Bool

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [SidebarTabDragPayload.typeIdentifier])
    }

    func dropEntered(info: DropInfo) {
        onLocationChange(info.location)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        onLocationChange(info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        onLocationChange(nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        let location = info.location
        onLocationChange(nil)
        return onPerformDrop(location)
    }
}
