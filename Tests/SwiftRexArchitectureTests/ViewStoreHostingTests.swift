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
        let node: GranularTracking<HState>
        let renders: Renders
        var body: some View {
            renders.hot += 1
            return Text("\(node.hot)")
        }
    }

    private struct ColdView: View {
        let node: GranularTracking<HState>
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
            ProjectionKeeper(strategy: strategy) {
                renders.makes += 1
                return store
            } content: { observed in
                ParentContent(observed: observed, renders: renders)
            }
        }
    }

    private struct ParentContent: View {
        let observed: ViewStore<HAction, HState>   // a plain-`let` receiver under both strategies
        let renders: Renders
        var body: some View {
            renders.parent += 1
            return VStack {
                Text("\(observed.state.tick)")
                HotView(node: observed.state, renders: renders)
                ColdView(node: observed.state, renders: renders)
            }
        }
    }

    // Flushes pending SwiftUI updates by forcing a layout pass — no run-loop spinning, which would hold the
    // main actor hostage and starve main-actor work in suites running in parallel.
    // An owner built with @OwnedStore inside a parent that keeps re-rendering (it reads `tick`).
    private struct OuterView: View {
        let outer: ViewStore<HAction, HState>
        let makeInner: @MainActor () -> Store<HAction, HState, Void>
        let renders: Renders
        var body: some View {
            renders.parent += 1
            return VStack {
                Text("\(outer.state.tick)")
                OwnerView(store: makeInner(), renders: renders)
            }
        }
    }

    private struct OwnerView: View {
        @OwnedStore var store: ViewStore<HAction, HState>
        let renders: Renders
        init(store: @autoclosure @escaping () -> Store<HAction, HState, Void>, renders: Renders) {
            _store = OwnedStore(wrappedValue: store())
            self.renders = renders
        }
        var body: some View {
            renders.hot += 1
            return Text("\(store.state.hot)")
        }
    }

    @MainActor
    private func settle(_ view: NSHostingView<some View>) {
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
    }

    @Suite("ViewStore — hosted in SwiftUI")
    @MainActor
    struct ViewStoreHostingTests {
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

        @Test func ownedStoreBuildsOnceAcrossParentReRenders() {
            let outerStore = makeHStore()
            let renders = Renders()
            let outer = ProjectionKeeper { outerStore } content: { outer in
                OuterView(
                    outer: outer,
                    makeInner: {
                        renders.makes += 1
                        return makeHStore()
                    },
                    renders: renders
                )
            }
            let host = NSHostingView(rootView: outer)
            host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
            settle(host)
            let parentBefore = renders.parent
            for _ in 0..<3 {
                outerStore.dispatch(.tick)
                settle(host)
            }
            #expect(renders.parent - parentBefore == 3)   // the parent re-rendered, re-initialising OwnerView…
            #expect(renders.makes == 1)                   // …but the owned store was built exactly once
        }

        @available(macOS 14, *)
        @Test func automaticUsesObservationWhereAvailable() {
            let store = makeHStore()
            let observed = store.viewStore()
            #expect(observed.testStrategy == .automatic)
            var sends = 0
            let cancellable = observed.testSignal.objectWillChange.sink { sends += 1 }
            _ = observed.state.hot
            store.dispatch(.hot)
            #expect(sends == 0) // Observation signalled it, not Combine
            cancellable.cancel()
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
