// SPDX-License-Identifier: Apache-2.0

// Stores built *from* an observed store (projections, buffers, child observed stores) read it to follow
// it — those reads must not register as view dependencies on the parent.

#if canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import Combine
    import Foundation
    import Observation
    import SwiftRex
    @testable import SwiftRexSwiftUI
    import Testing

    private final class Sends: @unchecked Sendable {
        // Bumped from synchronous callbacks on the main actor only.
        private let lock = NSLock()
        private var _value = 0
        var value: Int { lock.withLock { _value } }
        func bump() { lock.withLock { _value += 1 } }
    }

    private struct UState: Sendable, Equatable {
        var child = 0
        var other = 0
        var detail: Int?
    }

    private enum UAction: Sendable {
        case child, other, show, hide
    }

    @MainActor
    private func makeUStore() -> Store<UAction, UState, Void> {
        Store(
            initial: UState(),
            behavior: Reducer.reduce { (action: UAction, state: inout UState) in
                switch action {
                case .child: state.child += 1
                case .other: state.other += 1
                case .show: state.detail = 1
                case .hide: state.detail = nil
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @Suite("Stores built from an observed store")
    @MainActor
    struct ObservedUpstreamTests {
        @Test func childStoresDoNotPinAWholeStateDependencyOnTheParent() {
            let store = makeUStore()
            let parent = store.viewStore(.combine)
            let child = parent.projection(action: { $0 }, state: \.child).buffer().viewStore(.combine)
            _ = child.state.value
            let sends = Sends()
            let cancellable = parent.testSignal.objectWillChange.sink { sends.bump() }
            store.dispatch(.other)
            store.dispatch(.child)
            #expect(sends.value == 0)       // nobody *viewed* anything on the parent
            #expect(parent.testArmedCount == 0)
            #expect(child.currentState == 1) // yet the child still follows it
            cancellable.cancel()
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func buildingAChildInABodyDoesNotMakeTheBodyDependOnEverything() {
            let store = makeUStore()
            let view = store.viewStore()
            let fired = Sends()
            var child: ViewStore<UAction, Int>?
            withObservationTracking {
                child = view.projection(action: { $0 }, state: \.child).viewStore()   // what a host's `make` does
            } onChange: { fired.bump() }
            store.dispatch(.other)
            #expect(fired.value == 0)
            #expect(child?.currentState == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func closureTransposeDependsOnPresenceOnly() {
            let store = makeUStore()
            let view = store.viewStore()
            let fired = Sends()
            withObservationTracking {
                _ = view.traverse(action: { $0 }, state: { $0.detail })
            } onChange: { fired.bump() }
            store.dispatch(.other)
            #expect(fired.value == 0)       // an unrelated change doesn't redraw the caller
            store.dispatch(.show)
            #expect(fired.value == 1)       // the presence edge does
        }

        @Test func closureTransposeFollowsTheValue() {
            let store = makeUStore()
            let view = store.viewStore()
            #expect(view.traverse(action: { $0 }, state: { $0.detail }) == nil)
            store.dispatch(.show)
            let detail = view.traverse(action: { $0 }, state: { $0.detail })
            #expect(detail?.currentState == 1)
            store.dispatch(.hide)
            #expect(detail?.currentState == 1)     // lingers on its last value while SwiftUI tears it down
        }
    }
#endif
