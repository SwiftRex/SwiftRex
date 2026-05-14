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

@discardableResult
func subscribeAll<A: Sendable>(
    _ effect: Effect<A>,
    send: @escaping @Sendable (DispatchedAction<A>) -> Void,
    onComplete: @escaping @Sendable () -> Void = { }
) -> [SubscriptionToken] {
    effect.components.map { $0.subscribe(send, onComplete) }
}
