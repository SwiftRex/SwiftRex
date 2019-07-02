#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

extension PublisherType: Publisher {
    public typealias Output = Element
    public typealias Failure = ErrorType

    public func receive<S: Subscriber>(subscriber: S) where S.Failure == ErrorType, S.Input == Element {
        let subscriberType: SubscriberType<Element, ErrorType> = .init(
            onValue: { value in _ = subscriber.receive(value) },
            onCompleted: { error in
                if let error = error {
                    subscriber.receive(completion: .failure(error))
                    return
                }
                subscriber.receive(completion: .finished)
            }
        )
        let subscription: SwiftRex.Subscription = self.subscribe(subscriberType)
        subscriber.receive(subscription: subscription.asCancellable())
    }
}

extension Publisher {
    public func asPublisherType() -> PublisherType<Output, Failure> {
        return .init { (subscriber: SubscriberType<Output, Failure>) -> SwiftRex.Subscription in
            let cancellable = self.sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        subscriber.onCompleted(nil)
                    case let .failure(error):
                        subscriber.onCompleted(error)
                    }
                },
                receiveValue: { value in
                    subscriber.onValue(value)
                }
            )

            return CancellableSubscription(cancellable: cancellable)
        }
    }
}
#endif
