import Foundation
@testable import SwiftRex

/// Thread-safe value wrapper for tests capturing mutable state in `@Sendable` closures.
final class LockProtected<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T

    init(_ value: T) { _value = value }

    var value: T { lock.withLock { _value } }
    func set(_ v: T) { lock.withLock { _value = v } }
    func mutate(_ f: (inout T) -> Void) { lock.withLock { f(&_value) } }
}

/// Subscribes all components of an effect with the same send callback and a no-op complete,
/// mirroring how the Store subscribes (all components, same callback).
@discardableResult
func subscribeAll<A: Sendable>(
    _ effect: Effect<A>,
    send: @escaping @Sendable (DispatchedAction<A>) -> Void,
    onComplete: @escaping @Sendable () -> Void = { }
) -> [SubscriptionToken] {
    effect.components.map { $0.subscribe(send, onComplete) }
}
