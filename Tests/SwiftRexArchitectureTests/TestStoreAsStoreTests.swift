// SPDX-License-Identifier: Apache-2.0

// `TestStore` as a store: followed through its `stateStream`, projected, made into a `ViewStore`, dispatched to
// from a view — and supervising state-driven channels like the production `Store`.

#if canImport(AppKit) && canImport(SwiftUI) && canImport(Combine)
    import CoreFP
    import SwiftRex
    import SwiftRexArchitecture
    import SwiftRexTesting
    import SwiftUI
    import Testing

    struct TSChild: Sendable, Equatable { var n = 0 }

    enum TSChildAction: Sendable, Equatable { case set(Int) }

    struct TSState: Sendable, Equatable {
        var tally = 0
        var isLoading = false
        var child = TSChild()
        var connected = false
        var received: [Int] = []
    }

    @Prisms
    enum TSAction: Sendable, Equatable {
        case increment
        case load
        case loaded(Int)
        case child(TSChildAction)
        case connect(Bool)
        case received(Int)
    }

    private let tsBehavior = Behavior<TSAction, TSState, Void> { action, _ in
        switch action {
        case .increment:
            .reduce { $0.tally += 1 }
        case .load:
            .reduce { $0.isLoading = true }.produce { _ in .just(.loaded(42)) }
        case let .loaded(value):
            .reduce { state in
                state.isLoading = false
                state.tally = value
            }
        case let .child(.set(value)):
            .reduce { $0.child.n = value }
        case let .connect(on):
            .reduce { $0.connected = on }
        case let .received(value):
            .reduce { $0.received.append(value) }
        }
    }

    // While connected, a channel emits one value as it opens; disconnecting cancels it.
    private func supervising(_ cancels: LockedCount) -> Behavior<TSAction, TSState, Void> {
        tsBehavior.supervise { state in
            Supervision { _ in
                state.connected
                    ? [
                        Channel(id: "feed") { dispatch in
                            dispatch(.received(7))
                            return .cancelOnly { cancels.bump() }
                        }
                    ]
                    : []
            }
        }
    }

    private final class LockedCount: @unchecked Sendable {
        // Bumped from a channel's cancel, which runs on the main actor.
        private let lock = NSLock()
        private var n = 0
        var value: Int { lock.withLock { n } }
        func bump() { lock.withLock { n += 1 } }
    }

    @Suite("TestStore — as a store")
    @MainActor
    struct TestStoreAsStoreTests {
        @Test func itsStateStreamDeliversTheCurrentStateThenEveryChange() async {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            var seen: [Int] = []
            let token = store.stateStream.observe { seen.append($0.tally) }
            store.dispatch(.increment) { $0.tally = 1 }
            store.dispatch(.load) { $0.isLoading = true }
            await store.runEffects()
            store.receive(\.loaded) { value, state in
                state.isLoading = false
                state.tally = value
            }
            #expect(seen == [0, 1, 1, 42])
            _ = token
        }

        @Test func aProjectionDispatchesIntoItAndItsEffectsAreReceived() async {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let root = store.projection(action: { $0 }, state: { $0 })
            root.dispatch(.load) // a view-side dispatch: runs the behavior, no assertion
            #expect(store.state.isLoading)
            #expect(store.pendingEffects.count == 1)
            await store.runEffects()
            store.receive(\.loaded) { value, state in
                state.isLoading = false
                state.tally = value
            }
        }

        @Test func aScopeProjectionDispatchesThroughItsLane() {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let child = store.projection(.action(\.child).state(\.child))
            child.dispatch(.set(5))
            #expect(store.state.child.n == 5)
        }

        @Test func aViewStoreOverItReadsAndDispatches() async {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let viewStore = store.viewStore(.combine)
            #expect(viewStore.state.tally == 0)
            viewStore.dispatch(.increment)
            #expect(viewStore.state.tally == 1) // the view store follows the test store synchronously
            viewStore.dispatch(.load)
            await store.runEffects()
            store.receive(\.loaded) { value, state in
                state.isLoading = false
                state.tally = value
            }
            #expect(viewStore.state.tally == 42)
        }

        @Test func aBindingWritesThroughItsAction() {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let viewStore = store.viewStore(.combine)
            let binding: Binding<Int> = viewStore.binding(.state(\.child.n).action { TSAction.child(.set($0)) })
            binding.wrappedValue = 9
            #expect(store.state.child.n == 9)
            #expect(binding.wrappedValue == 9)
        }

        @Test func aDerivedChildOfItsViewStoreDispatchesIntoIt() {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let child = store.viewStore(.combine).projection(.action(\.child).state(\.child)).viewStore(.combine)
            child.dispatch(.set(3))
            #expect(store.state.child.n == 3)
            #expect(child.state.n == 3)
        }

        @Test func ignoringActionsDropsViewSideDispatchesOnly() {
            let store = TestStore(initial: TSState(), behavior: tsBehavior, environment: ())
            let viewStore = store.viewStore(.combine)
            store.isIgnoringActions = true
            viewStore.dispatch(.increment)
            #expect(store.state.tally == 0)
            store.dispatch(.increment) { $0.tally = 1 } // the test's own dispatch still runs
        }
    }

    @Suite("TestStore — supervision")
    @MainActor
    struct TestStoreSupervisionTests {
        @Test func aStateChangeOpensTheSupervisedChannelAndItsOutputIsReceived() async {
            let cancels = LockedCount()
            let store = TestStore(initial: TSState(), behavior: supervising(cancels), environment: ())
            store.dispatch(.connect(true)) { $0.connected = true }
            await store.runEffects()
            store.receive(\.received) { value, state in state.received.append(value) }
            store.dispatch(.connect(false)) { $0.connected = false }
            #expect(cancels.value == 1) // the state no longer keeps it: cancelled
        }

        @Test func theInitialStateOpensItsChannels() async {
            let cancels = LockedCount()
            var initial = TSState()
            initial.connected = true
            let store = TestStore(initial: initial, behavior: supervising(cancels), environment: ())
            await store.runEffects()
            store.receive(\.received) { value, state in state.received.append(value) }
        }

        @Test func aChannelTheStateStillKeepsAtTheEndIsNotAFailure() async {
            // Exhaustive mode: the supervised channel is still open when the store goes away, and that's the state's
            // call, not a leak — no issue is recorded (an effect channel left open still is).
            let cancels = LockedCount()
            let store = TestStore(initial: TSState(), behavior: supervising(cancels), environment: ())
            store.dispatch(.connect(true)) { $0.connected = true }
            await store.runEffects()
            store.receive(\.received) { value, state in state.received.append(value) }
        }
    }
#endif
