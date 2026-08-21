import CoreGraphics
import Foundation
import Testing

#if canImport(cmux_DEV)
@testable import cmux_DEV
#elseif canImport(cmux)
@testable import cmux
#endif

@Suite("Fleet canvas layout geometry")
struct FleetCanvasLayoutSolutionTests {
    private let a = UUID()
    private let b = UUID()
    private let c = UUID()
    private let canvas = CGRect(x: 0, y: 0, width: 1600, height: 900)
    private let spacing: CGFloat = 16

    private func row(_ ids: [UUID], weights: [CGFloat]? = nil) -> FleetCanvasLayoutNode {
        .container(
            axis: .horizontal,
            members: ids.map { .workspace($0) },
            weights: weights ?? Array(repeating: 1, count: ids.count)
        )
    }

    @Test("A single card fills the canvas")
    func singleCardFillsCanvas() {
        let solution = FleetCanvasLayoutNode.workspace(a).solve(in: canvas, spacing: spacing)

        #expect(solution.frames.count == 1)
        #expect(solution.frames[0].rect == canvas)
        #expect(solution.dividers.isEmpty)
    }

    @Test("Three equal members are equal width and fill the canvas")
    func threeEqualCardsFillCanvas() {
        let solution = row([a, b, c]).solve(in: canvas, spacing: spacing)
        let widths = solution.frames.map(\.rect.width)

        #expect(widths.count == 3)
        #expect(abs(widths[0] - widths[1]) < 0.001)
        #expect(abs(widths[1] - widths[2]) < 0.001)
        #expect(abs(widths.reduce(0, +) + spacing * 2 - canvas.width) < 0.001)
        let satisfiesAll0 = solution.frames.allSatisfy { abs($0.rect.height - canvas.height) < 0.001 }
        #expect(satisfiesAll0)
    }

    @Test("Weights drive member sizes")
    func weightsDriveSizes() {
        let solution = row([a, b], weights: [3, 1]).solve(in: canvas, spacing: spacing)

        #expect(abs(solution.frames[0].rect.width / solution.frames[1].rect.width - 3) < 0.01)
    }

    @Test("One card left and two stacked right lays out as expected")
    func nestedLayoutFillsCanvas() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )
        let solution = tree.solve(in: canvas, spacing: spacing)
        let byId = Dictionary(uniqueKeysWithValues: solution.frames.map { ($0.workspaceId, $0.rect) })

        #expect(abs(byId[a]!.height - canvas.height) < 0.001)
        #expect(abs(byId[b]!.height + byId[c]!.height + spacing - canvas.height) < 0.001)
        #expect(abs(byId[b]!.minX - byId[c]!.minX) < 0.001)
        #expect(byId[b]!.minY < byId[c]!.minY)
        let satisfiesAll1 = solution.frames.allSatisfy { canvas.insetBy(dx: -0.5, dy: -0.5).contains($0.rect) }
        #expect(satisfiesAll1)
    }

    @Test("A container of N members yields N-1 dividers, each addressable")
    func dividerCountMatchesMembers() {
        let solution = row([a, b, c]).solve(in: canvas, spacing: spacing)

        #expect(solution.dividers.count == 2)
        #expect(solution.dividers.map(\.leadingIndex) == [0, 1])
        for divider in solution.dividers {
            #expect(divider.axis == .horizontal)
            #expect(divider.usableLength > 0)
            #expect(divider.fractions.count == 3)
        }
    }

    @Test("Nested containers each contribute their own dividers")
    func nestedContainersHaveOwnDividers() {
        let tree = FleetCanvasLayoutNode.container(
            axis: .horizontal,
            members: [
                .workspace(a),
                .container(axis: .vertical, members: [.workspace(b), .workspace(c)], weights: [1, 1]),
            ],
            weights: [1, 1]
        )
        let solution = tree.solve(in: canvas, spacing: spacing)

        #expect(solution.dividers.count == 2)
        #expect(Set(solution.dividers.map(\.axis)) == Set([.horizontal, .vertical]))
        for divider in solution.dividers {
            #expect(tree.node(at: divider.path) != nil)
        }
    }

    @Test("Dividers sit in the gap between their members")
    func dividersSitInTheGap() {
        let solution = row([a, b], weights: [2, 3]).solve(in: canvas, spacing: spacing)
        let divider = solution.dividers[0]

        #expect(abs(divider.rect.minX - solution.frames[0].rect.maxX) < 0.001)
        #expect(abs(divider.rect.maxX - solution.frames[1].rect.minX) < 0.001)
        #expect(abs(divider.rect.width - spacing) < 0.001)
    }

    @Test("A tiny canvas still produces positive sizes")
    func tinyCanvasStaysPositive() {
        let solution = row([a, b, c]).solve(in: CGRect(x: 0, y: 0, width: 10, height: 10), spacing: spacing)

        #expect(solution.frames.count == 3)
        let satisfiesAll2 = solution.frames.allSatisfy { $0.rect.width > 0 && $0.rect.height > 0 }
        #expect(satisfiesAll2)
    }
}
