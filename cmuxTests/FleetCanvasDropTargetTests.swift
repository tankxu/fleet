import CoreGraphics
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas drop targets")
struct FleetCanvasDropTargetTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private let size = CGSize(width: 400, height: 300)

    @Test("The nearest edge wins, divided by the card's diagonals")
    func nearestEdgeWins() {
        #expect(FleetCanvasDropTarget.edge(location: CGPoint(x: 20, y: 150), size: size) == .leading)
        #expect(FleetCanvasDropTarget.edge(location: CGPoint(x: 380, y: 150), size: size) == .trailing)
        #expect(FleetCanvasDropTarget.edge(location: CGPoint(x: 200, y: 10), size: size) == .top)
        #expect(FleetCanvasDropTarget.edge(location: CGPoint(x: 200, y: 290), size: size) == .bottom)
    }

    @Test("A zero-sized card degrades instead of dividing by zero")
    func zeroSizeDegrades() {
        #expect(FleetCanvasDropTarget.edge(location: .zero, size: .zero) == .trailing)
    }

    @Test("Each edge maps to the group axis it creates")
    func edgesMapToAxes() {
        #expect(FleetCanvasLayoutEdge.leading.axis == .horizontal)
        #expect(FleetCanvasLayoutEdge.trailing.axis == .horizontal)
        #expect(FleetCanvasLayoutEdge.top.axis == .vertical)
        #expect(FleetCanvasLayoutEdge.bottom.axis == .vertical)
        #expect(FleetCanvasLayoutEdge.leading.placesFirst)
        #expect(FleetCanvasLayoutEdge.top.placesFirst)
        #expect(!FleetCanvasLayoutEdge.trailing.placesFirst)
        #expect(!FleetCanvasLayoutEdge.bottom.placesFirst)
    }

    @Test("Dropping a card on itself changes nothing")
    func selfDropChangesNothing() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b)],
            weights: [1, 1]
        )

        #expect(!FleetCanvasDropTarget.changesLayout(
            draggedWorkspaceId: a,
            targetWorkspaceId: a,
            edge: .leading,
            tree: tree
        ))
    }

    @Test("Any drop onto another card groups them, so it is always a change")
    func dropOntoCardIsAlwaysAChange() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b)],
            weights: [1, 1]
        )

        // Even the side `a` already sits on: dropping on a card means "pair with
        // this card", which nests a new container where the target was.
        for edge in FleetCanvasLayoutEdge.allCases {
            #expect(
                FleetCanvasDropTarget.changesLayout(
                    draggedWorkspaceId: a,
                    targetWorkspaceId: b,
                    edge: edge,
                    tree: tree
                ),
                "edge=\(edge)"
            )
        }
    }

    @Test("A workspace from another window is rejected")
    func foreignWorkspaceRejected() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [.workspace(a), .workspace(b)],
            weights: [1, 1]
        )

        #expect(!FleetCanvasDropTarget.changesLayout(
            draggedWorkspaceId: UUID(),
            targetWorkspaceId: a,
            edge: .leading,
            tree: tree
        ))
    }
}
