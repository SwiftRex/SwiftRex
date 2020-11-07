#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SwiftRex.SubscriptionType {
    public func asCancellable() -> Cancellable & Combine.Subscription {
        if let cancellable = self as? Cancellable & Combine.Subscription { return cancellable }
        return CancellableSubscription(subscription: self)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Cancellable {
    public func asSubscriptionType() -> SwiftRex.SubscriptionType {
        if let subscription = self as? SwiftRex.SubscriptionType { return subscription }
        return CancellableSubscription(cancellable: self)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
private class CancellableSubscription: Cancellable, SwiftRex.SubscriptionType, Combine.Subscription {
    func request(_ demand: Subscribers.Demand) {
        guard let combineSubscription = cancellable as? Combine.Subscription else { return }
        combineSubscription.request(demand)
    }

    let cancellable: Cancellable

    init(cancellable: Cancellable) {
        self.cancellable = cancellable
    }

    init(subscription: SwiftRex.SubscriptionType) {
        self.cancellable = AnyCancellable {
            subscription.unsubscribe()
        }
    }

    func unsubscribe() {
        cancellable.cancel()
    }

    func cancel() {
        cancellable.cancel()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Set where Element == AnyCancellable {
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public mutating func store(subscription: SwiftRex.SubscriptionType) {
        let anyCancellable = AnyCancellable { subscription.asCancellable().cancel() }
        anyCancellable.store(in: &self)
    }
}

// This is not supported by Swift availability attributes:
// @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
// extension Set: SwiftRex.SubscriptionCollection where Element: Cancellable {
//     public mutating func store(subscription: SubscriptionType) {
//
//     }
// }

extension SubscriptionType {
    /// Allow to add a subscription to a subscription collection, which is an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your
    /// chosen reactive framework
    /// - Parameter subscriptionCollection: an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your chosen reactive framework
    @available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
    public func cancelled(by subscriptionCollection: inout Set<AnyCancellable>) {
        subscriptionCollection.store(subscription: self)
    }
}
#endif
