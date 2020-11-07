#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PublisherType: Publisher {
    public typealias Output = Element
    public typealias Failure = ErrorType

    public func receive<S: Subscriber>(subscriber: S) where S.Failure == ErrorType, S.Input == Element {
        let subscriberType = subscriber.asSubscriberType()
        let subscription: SwiftRex.SubscriptionType = self.subscribe(subscriberType)
        subscriber.receive(subscription: subscription.asCancellable())
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher {
    public func asPublisherType() -> PublisherType<Output, Failure> {
        .init { (subscriber: SubscriberType<Output, Failure>) -> SwiftRex.SubscriptionType in
            self.subscribe(subscriber)
            return AnyCancellable { }.asSubscriptionType()
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension PublisherType {
    public static func lift<FromOutput>(_ transform: @escaping (FromOutput) -> Output) -> (PublisherType<FromOutput, Failure>)
    -> PublisherType<Output, Failure> { { originalPublisher in
            originalPublisher.map(transform).asPublisherType()
        }
    }
}
#endif
