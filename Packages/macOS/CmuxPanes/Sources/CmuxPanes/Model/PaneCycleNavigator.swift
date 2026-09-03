public import Bonsplit
public import Foundation

/// Resolves wrapping previous/next pane focus targets from a stable pane order.
public struct PaneCycleNavigator {
    /// Creates a stateless pane-cycle navigator.
    public init() {}

    /// Returns the pane reached by cycling one step from the currently focused pane.
    ///
    /// `orderedPaneIds` is the authoritative visual/tree order. `livePaneIds`
    /// is the controller's current pane set, used to discard stale ordered ids
    /// before indexing and to return the concrete `PaneID` value the controller
    /// expects.
    ///
    /// - Parameters:
    ///   - orderedPaneIds: Pane UUIDs in stable visual/tree order.
    ///   - livePaneIds: Pane ids currently owned by the split controller.
    ///   - focusedPaneId: The currently focused pane.
    ///   - forward: `true` for next, `false` for previous.
    /// - Returns: The target pane, or `nil` when cycling is not possible.
    public func targetPane(
        orderedPaneIds: [UUID],
        livePaneIds: [PaneID],
        focusedPaneId: PaneID?,
        forward: Bool
    ) -> PaneID? {
        var panesById: [UUID: PaneID] = [:]
        for paneId in livePaneIds {
            panesById[paneId.id] = paneId
        }

        let orderedLivePaneIds = orderedPaneIds.compactMap { panesById[$0] }
        guard orderedLivePaneIds.count > 1,
              let focusedPaneId,
              let currentIndex = orderedLivePaneIds.firstIndex(of: focusedPaneId) else {
            return nil
        }

        let targetIndex = forward
            ? (currentIndex + 1) % orderedLivePaneIds.count
            : (currentIndex - 1 + orderedLivePaneIds.count) % orderedLivePaneIds.count
        return orderedLivePaneIds[targetIndex]
    }
}

/// A concrete surface target resolved from pane order and per-pane tab order.
public struct SurfaceCycleTarget: Equatable, Sendable {
    public let paneId: PaneID
    public let tabId: TabID

    public init(paneId: PaneID, tabId: TabID) {
        self.paneId = paneId
        self.tabId = tabId
    }
}

/// Resolves wrapping previous/next surface targets across every split pane.
public struct SurfaceCycleNavigator {
    /// Creates a stateless surface-cycle navigator.
    public init() {}

    /// Returns the surface reached by cycling one step through pane and tab order.
    ///
    /// Panes follow the authoritative visual/tree order. Tabs within each pane
    /// keep their controller order, preserving existing tab-only navigation while
    /// allowing the cycle to cross into simultaneously visible split panes.
    public func targetSurface(
        orderedPaneIds: [UUID],
        livePaneIds: [PaneID],
        tabsByPaneId: [UUID: [TabID]],
        focusedPaneId: PaneID?,
        selectedTabId: TabID?,
        forward: Bool
    ) -> SurfaceCycleTarget? {
        var panesById: [UUID: PaneID] = [:]
        for paneId in livePaneIds {
            panesById[paneId.id] = paneId
        }

        let orderedTargets = orderedPaneIds.flatMap { paneUUID -> [SurfaceCycleTarget] in
            guard let paneId = panesById[paneUUID] else { return [] }
            return (tabsByPaneId[paneUUID] ?? []).map {
                SurfaceCycleTarget(paneId: paneId, tabId: $0)
            }
        }
        guard orderedTargets.count > 1,
              let focusedPaneId,
              let selectedTabId,
              let currentIndex = orderedTargets.firstIndex(where: {
                  $0.paneId == focusedPaneId && $0.tabId == selectedTabId
              }) else {
            return nil
        }

        let targetIndex = forward
            ? (currentIndex + 1) % orderedTargets.count
            : (currentIndex - 1 + orderedTargets.count) % orderedTargets.count
        return orderedTargets[targetIndex]
    }
}
