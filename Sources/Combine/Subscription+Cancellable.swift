#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension SwiftRex.Subscription {
    public func asCancellable() -> CancellableSubscription {
        return CancellableSubscription(subscription: self)
    }
}

public class CancellableSubscription: Cancellable, SwiftRex.Subscription, Combine.Subscription {
    public func request(_ demand: Subscribers.Demand) {
        // No support for backpressure
    }

    let cancellable: Cancellable

    public init(cancellable: Cancellable) {
        self.cancellable = cancellable
    }

    public init(subscription: SwiftRex.Subscription) {
        self.cancellable = AnyCancellable {
            subscription.unsubscribe()
        }
    }

    public init(combineSubscription: Combine.Subscription) {
        self.cancellable = AnyCancellable {
            combineSubscription.cancel()
        }
    }

    public func unsubscribe() {
        cancellable.cancel()
    }

    public func cancel() {
        cancellable.cancel()
    }
}
#endif
