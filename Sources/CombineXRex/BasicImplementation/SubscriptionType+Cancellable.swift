import CombineX
import CXFoundation
import Foundation
import SwiftRex

extension SwiftRex.SubscriptionType {
    public func asCancellable() -> CombineX.Cancellable & CombineX.Subscription {
        if let cancellable = self as? CombineX.Cancellable & CombineX.Subscription { return cancellable }
        return CancellableSubscription(subscription: self)
    }
}

extension CombineX.Cancellable {
    public func asSubscriptionType() -> SwiftRex.SubscriptionType {
        if let subscription = self as? SwiftRex.SubscriptionType { return subscription }
        return CancellableSubscription(cancellable: self)
    }
}

private class CancellableSubscription: CombineX.Cancellable, SwiftRex.SubscriptionType, CombineX.Subscription {
    func request(_ demand: Subscribers.Demand) {
        guard let combineSubscription = cancellable as? CombineX.Subscription else { return }
        combineSubscription.request(demand)
    }

    let cancellable: Cancellable

    init(cancellable: Cancellable) {
        self.cancellable = cancellable
    }

    init(subscription: SwiftRex.SubscriptionType) {
        self.cancellable = CombineX.AnyCancellable {
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

extension Set where Element == CombineX.AnyCancellable {
    public mutating func store(subscription: SwiftRex.SubscriptionType) {
        let anyCancellable = CombineX.AnyCancellable { subscription.asCancellable().cancel() }
        anyCancellable.store(in: &self)
    }
}

extension SubscriptionType {
    /// Allow to add a subscription to a subscription collection, which is an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your
    /// chosen reactive framework
    /// - Parameter subscriptionCollection: an abstraction for `DisposeBag` or `Set<AnyCancellable` depending on your chosen reactive framework
    public func cancelled(by subscriptionCollection: inout Set<CombineX.AnyCancellable>) {
        subscriptionCollection.store(subscription: self)
    }
}
