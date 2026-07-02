#if canImport(Observation) && canImport(SwiftUI)
import SwiftRex
@testable import SwiftRexArchitecture
import Testing

// Exercises the generic ViewStore — seeds from the store, re-reads on any change (dispatched
// through it or directly on the underlying store), and forwards dispatch.

@Suite("ViewStore")
@MainActor
struct ViewStoreTests {
    private struct S: Sendable, Equatable { var count = 0; var label = "a" }
    private enum A: Sendable { case increment, setLabel(String) }

    private func makeStore() -> Store<A, S, Void> {
        Store(
            initial: S(),
            behavior: Reducer.reduce { (a: A, s: inout S) in
                switch a {
                case .increment:       s.count += 1
                case .setLabel(let l): s.label = l
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func seedsStateFromStore() {
        let store = makeStore()
        store.dispatch(.increment)
        let vs = ViewStore(store)
        #expect(vs.state.count == 1)   // seeded from the store's current state
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func stateUpdatesOnDispatchThroughViewStore() async {
        let store = makeStore()
        let vs = ViewStore(store)
        vs.dispatch(.increment)
        await Task.yield()
        #expect(vs.state.count == 1)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func stateUpdatesWhenUnderlyingStoreChanges() async {
        let store = makeStore()
        let vs = ViewStore(store)
        store.dispatch(.setLabel("z"))   // change the store directly
        await Task.yield()
        #expect(vs.state.label == "z")   // ViewStore observed it
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func dispatchIsForwardedToStore() async {
        let store = makeStore()
        let vs = ViewStore(store)
        vs.dispatch(.setLabel("done"))
        await Task.yield()
        #expect(store.state.label == "done")
    }
}
#endif
