#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension PublisherType: Publisher {
    public typealias Output = Element
    public typealias Failure = ErrorType

    public func receive<S: Subscriber>(subscriber: S) where S.Failure == ErrorType, S.Input == Element {
        let subscriberType = subscriber.asSubscriberType()
        let subscription: SwiftRex.SubscriptionType = self.subscribe(subscriberType)
        subscriber.receive(subscription: subscription.asCancellable())
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension Publisher {
    public func asPublisherType() -> PublisherType<Output, Failure> {
        .init { (subscriber: SubscriberType<Output, Failure>) -> SwiftRex.SubscriptionType in
            self.subscribe(subscriber)
            return AnyCancellable { }.asSubscription()
        }
    }
}
#endif
