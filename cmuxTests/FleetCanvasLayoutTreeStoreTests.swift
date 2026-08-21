import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas layout tree store")
struct FleetCanvasLayoutTreeStoreTests {
    private let a = UUID()
    private let b = UUID()

    @Test("A tree round-trips through the stored string")
    func treeRoundTrips() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .vertical,
            members: [.workspace(a), .workspace(b)],
            weights: [0.3, 0.7]
        )
        let raw = FleetCanvasLayoutTreeStore.encode(tree)

        #expect(FleetCanvasLayoutTreeStore.tree(in: raw) == tree)
    }

    @Test("Corrupt or empty storage degrades to no tree")
    func corruptStorageDegrades() {
        for raw in ["", "not json", "{", "[1,2,3]", "{\"workspace\":\"nope\"}"] {
            #expect(FleetCanvasLayoutTreeStore.tree(in: raw) == nil, "raw=\(raw)")
        }
    }

    @Test("Encoding no tree yields an empty string rather than a literal null")
    func encodingNilIsEmpty() {
        #expect(FleetCanvasLayoutTreeStore.encode(nil).isEmpty)
    }

}
