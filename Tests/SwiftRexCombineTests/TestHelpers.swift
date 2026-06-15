import Foundation
import SwiftRex

final class LockProtected<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { _value = value }
    var value: T { lock.withLock { _value } }
    func set(_ v: T) { lock.withLock { _value = v } }
    func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&_value) } }
}

// SubscriptionToken cancels its effect when released, so discarding the tokens below would cancel
// an in-flight async effect mid-test. Retain them for the test process so discard is safe; the
// dedicated cancellation tests use direct `subscribe` to exercise release/cancel behavior.
private let _effectSubscriptionSink = LockProtected<[SubscriptionToken]>([])

@discardableResult
func subscribeAll<A: Sendable>(
    _ effect: Effect<A>,
    send: @escaping @Sendable (DispatchedAction<A>) -> Void,
    onComplete: @escaping @Sendable () -> Void = { }
) -> [SubscriptionToken] {
    let tokens = effect.components.map { $0.subscribe(send, onComplete) }
    _effectSubscriptionSink.mutate { $0.append(contentsOf: tokens) }
    return tokens
}
