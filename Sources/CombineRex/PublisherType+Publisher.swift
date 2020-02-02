import Combine
import Foundation
import SwiftRex

extension PublisherType: Publisher {
    public typealias Output = Element
    public typealias Failure = ErrorType

    public func receive<S: Subscriber>(subscriber: S) where S.Failure == ErrorType, S.Input == Element {
        let subscriberType = subscriber.asSubscriberType()
        let subscription: SwiftRex.SubscriptionType = self.subscribe(subscriberType)
        subscriber.receive(subscription: subscription.asCancellable())
    }
}

extension Publisher {
    public func asPublisherType() -> PublisherType<Output, Failure> {
        .init { (subscriber: SubscriberType<Output, Failure>) -> SwiftRex.SubscriptionType in
            self.subscribe(subscriber)
            return AnyCancellable { }.asSubscriptionType()
        }
    }
}

extension PublisherType {
    public static func lift<FromOutput>(_ transform: @escaping (FromOutput) -> Output) -> (PublisherType<FromOutput, Failure>)
    -> PublisherType<Output, Failure> {
        return { originalPublisher in
            originalPublisher.map(transform).asPublisherType()
        }
    }
}
