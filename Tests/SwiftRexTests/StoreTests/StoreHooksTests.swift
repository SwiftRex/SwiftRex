@testable import SwiftRex
import Testing

@Suite("Store — Void init & reentrance diagnostics")
@MainActor
struct StoreHooksTests {
    @Test func voidEnvironmentBehaviorConvenienceInit() {
        // The new `Store(initial:behavior:)` overload defaults `environment` to `()`.
        let store = Store(initial: 5, behavior: Reducer<Int, Int>.reduce { action, state in state += action }.asBehavior())
        store.dispatch(3)
        #expect(store.state == 8)
    }

    @Test func reentranceCycleFiresHookAndDropsQueue() {
        let savedThreshold = StoreHooks.reentranceThreshold
        let savedHandler = StoreHooks.onReentranceDetected
        defer {
            StoreHooks.reentranceThreshold = savedThreshold
            StoreHooks.onReentranceDetected = savedHandler
        }

        var captured: StoreReentranceInfo?
        StoreHooks.reentranceThreshold = 10
        StoreHooks.onReentranceDetected = { captured = $0 }   // capture instead of trapping

        let store = Store(initial: 0, reducer: Reducer<Int, Int>.reduce { _, state in state += 1 })
        // A didChange observer that re-dispatches on every mutation → a runaway loop.
        let token = store.observe(willChange: {}, didChange: { [weak store] in store?.dispatch(1) })

        store.dispatch(1)   // kicks off the cycle; the diagnostic must stop it (no hang)

        #expect(captured != nil)
        #expect(captured?.drainedCount == 11)        // trips on the 11th drain (threshold 10)
        #expect(captured?.threshold == 10)
        #expect(store.state == 10)                   // 10 mutations ran before the queue was dropped
        _ = token
    }
}
