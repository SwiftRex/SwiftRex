// SPDX-License-Identifier: Apache-2.0

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
    import AppKit
    import SwiftRex
    @testable import SwiftRexSwiftUI
    import SwiftUI
    import Testing

    private struct HState: Sendable, Equatable {
        var hot = 0
        var cold = 0
        var tick = 0
    }

    private enum HAction: Sendable {
        case hot, cold, tick
    }

    @MainActor
    private final class Renders {
        var parent = 0
        var hot = 0
        var cold = 0
        var makes = 0
    }

    @MainActor
    private func makeHStore() -> Store<HAction, HState, Void> {
        Store(
            initial: HState(),
            behavior: Reducer.reduce { (action: HAction, state: inout HState) in
                switch action {
                case .hot: state.hot += 1
                case .cold: state.cold += 1
                case .tick: state.tick += 1
                }
            }.asBehavior(),
            environment: ()
        )
    }

    private struct HotView: View {
        let node: StateNode<ObservableStore<HAction, HState>, HState>
        let renders: Renders
        var body: some View {
            renders.hot += 1
            return Text("\(node.hot)")
        }
    }

    private struct ColdView: View {
        let node: StateNode<ObservableStore<HAction, HState>, HState>
        let renders: Renders
        var body: some View {
            renders.cold += 1
            return Text("\(node.cold)")
        }
    }

    // The parent reads `tick` only; children receive the root node and read their own paths.
    private struct ParentView: View {
        let store: Store<HAction, HState, Void>
        let strategy: ViewStrategy
        let renders: Renders
        var body: some View {
            ObservableStoreHost {
                renders.makes += 1
                return store.observable(strategy)
            } content: { observed in
                ParentContent(observed: observed, renders: renders)
            }
        }
    }

    private struct ParentContent: View {
        @ObservedObject var observed: ObservableStore<HAction, HState>
        let renders: Renders
        var body: some View {
            renders.parent += 1
            return VStack {
                Text("\(observed.tick)")
                HotView(node: observed[dynamicMember: \HState.self], renders: renders)
                ColdView(node: observed[dynamicMember: \HState.self], renders: renders)
            }
        }
    }

    // Flushes pending SwiftUI updates by forcing a layout pass — no run-loop spinning, which would hold the
    // main actor hostage and starve main-actor work in suites running in parallel.
    @MainActor
    private func settle(_ view: NSHostingView<some View>) {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    @Suite("ObservableStore — hosted in SwiftUI")
    @MainActor
    struct ObservableStoreHostingTests {
        @available(macOS 14, *)
        @Test func observationRedrawsOnlyTheReaderOfAChangedPath() {
            let store = makeHStore()
            let renders = Renders()
            let host = NSHostingView(rootView: ParentView(store: store, strategy: .observation, renders: renders))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            settle(host)
            let base = (renders.parent, renders.hot, renders.cold)
            for _ in 0..<5 {
                store.dispatch(.hot)
                settle(host)
            }
            #expect(renders.hot - base.1 == 5)
            #expect(renders.cold == base.2)
            #expect(renders.parent == base.0)
            #expect(renders.makes == 1)
        }

        @Test func combineRedrawsNodeHoldersWhenTheirPathChanged() {
            let store = makeHStore()
            let renders = Renders()
            let host = NSHostingView(rootView: ParentView(store: store, strategy: .combine, renders: renders))
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            settle(host)
            let hotBefore = renders.hot
            store.dispatch(.hot)
            settle(host)
            #expect(renders.hot > hotBefore)
            let parentBefore = renders.parent
            store.dispatch(.tick) // unread? no — the parent reads `tick`
            settle(host)
            #expect(renders.parent > parentBefore)
            #expect(renders.makes == 1)
        }
    }
#endif
