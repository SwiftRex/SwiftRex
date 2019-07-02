#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension SwiftRex.Subscription {
    public func asCancellable() -> CancellableSubscription {
        return CancellableSubscription(subscription: self)
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
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
