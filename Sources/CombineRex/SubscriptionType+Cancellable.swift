import Combine
import Foundation
import SwiftRex

extension SwiftRex.SubscriptionType {
    public func asCancellable() -> Cancellable & Combine.Subscription {
        if let cancellable = self as? Cancellable & Combine.Subscription { return cancellable }
        return CancellableSubscription(subscription: self)
    }
}

extension Cancellable {
    public func asSubscriptionType() -> SwiftRex.SubscriptionType {
        if let subscription = self as? SwiftRex.SubscriptionType { return subscription }
        return CancellableSubscription(cancellable: self)
    }
}

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

extension Array: SwiftRex.SubscriptionCollection where Element == AnyCancellable {
    public mutating func store(subscription: SwiftRex.SubscriptionType) {
        let anyCancellable = AnyCancellable { subscription.asCancellable().cancel() }
        anyCancellable.store(in: &self)
    }
}
