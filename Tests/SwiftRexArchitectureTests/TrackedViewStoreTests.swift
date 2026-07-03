#if canImport(Observation) && canImport(SwiftUI)
import Foundation
import Observation
import SwiftRex
@testable import SwiftRexArchitecture
import SwiftUI
import Testing

/// Thread-safe flag for capturing mutable state in the `@Sendable` `onChange` closure.
private final class LockProtected<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T { lock.withLock { _value } }
    func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&_value) } }
}

// A @Tracked view state used directly as a store's State (no projection needed for the test).
@Tracked
private struct TVS: Sendable, Equatable {
    var title: String
    var count: Int
}

private enum TVA: Sendable {
    case setTitle(String)
    case increment
}

@Suite("TrackedViewStore + @Tracked")
@MainActor
struct TrackedViewStoreTests {
    private func makeStore() -> Store<TVA, TVS, Void> {
        Store(
            initial: TVS(title: "a", count: 0),
            behavior: Reducer.reduce { (action: TVA, state: inout TVS) in
                switch action {
                case .setTitle(let t): state.title = t
                case .increment:       state.count += 1
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func seedsMirrorFromState() {
        let store = makeStore()
        store.dispatch(.increment)
        let vs = TrackedViewStore(store)
        #expect(vs.state.title == "a")
        #expect(vs.state.count == 1)
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func updatesMirrorInPlaceKeepingIdentity() async {
        let store = makeStore()
        let vs = TrackedViewStore(store)
        let mirror = vs.state                 // capture the @Observable instance
        store.dispatch(.setTitle("z"))
        await Task.yield()
        #expect(vs.state.title == "z")
        #expect(vs.state === mirror)          // same instance — updated in place, not reassigned
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func dispatchIsForwardedToStore() async {
        let store = makeStore()
        let vs = TrackedViewStore(store)
        vs.dispatch(.increment)
        await Task.yield()
        #expect(store.state.count == 1)
    }

    // TrackedViewStore: StoreType (State == the mirror) ⇒ binding reads a tracked field, dispatches on set.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func bindingOnTrackedMirror() async {
        let store = makeStore()
        let vs = TrackedViewStore(store)
        let binding: Binding<String> = vs.binding(\.title, set: { .setTitle($0) })
        #expect(binding.wrappedValue == "a")
        binding.wrappedValue = "z"
        await Task.yield()
        #expect(vs.state.title == "z")
    }

    // Proves field-level granularity: observing only `title` does not fire when `count` changes,
    // and does fire when `title` changes — exactly what the in-place field-diff enables.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @Test func observingOneFieldIgnoresChangesToAnother() async {
        let store = makeStore()
        let vs = TrackedViewStore(store)
        let fired = LockProtected(false)
        withObservationTracking { _ = vs.state.title } onChange: { fired.mutate { $0 = true } }

        store.dispatch(.increment)            // count changes; title untouched (field-diff skips it)
        await Task.yield()
        #expect(fired.value == false)         // title observer did NOT fire — granular

        store.dispatch(.setTitle("z"))        // title changes
        await Task.yield()
        #expect(fired.value == true)
    }
}
#endif
