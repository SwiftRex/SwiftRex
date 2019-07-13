#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension SwiftRex.Subscription {
    public func asCancellable() -> Cancellable & Combine.Subscription {
        if let cancellable = self as? Cancellable & Combine.Subscription { return cancellable }
        return CancellableSubscription(subscription: self)
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension Cancellable {
    public func asSubscription() -> SwiftRex.Subscription {
        if let subscription = self as? SwiftRex.Subscription { return subscription }
        return CancellableSubscription(cancellable: self)
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
private class CancellableSubscription: Cancellable, SwiftRex.Subscription, Combine.Subscription {
    func request(_ demand: Subscribers.Demand) {
        guard let combineSubscription = cancellable as? Combine.Subscription else { return }
        combineSubscription.request(demand)
    }

    let cancellable: Cancellable

    init(cancellable: Cancellable) {
        self.cancellable = cancellable
    }

    init(subscription: SwiftRex.Subscription) {
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

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension RangeReplaceableCollection where Element == AnyCancellable {
    @available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
    public mutating func store(subscription: SwiftRex.Subscription) {
        let anyCancellable = AnyCancellable { subscription.asCancellable().cancel() }
        anyCancellable.store(in: &self)
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
public typealias CancellableArray = [AnyCancellable]

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension CancellableArray: SwiftRex.SubscriptionCollection { }
#endif
