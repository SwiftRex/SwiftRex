#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension SubscriberType: Subscriber {
    public var combineIdentifier: CombineIdentifier {
        CombineIdentifier()
    }

    public func receive(subscription: Combine.Subscription) {
        onSubscribe(subscription.asSubscriptionType())
    }

    public func receive(_ input: Element) -> Subscribers.Demand {
        onValue(input)
        return .none
    }

    public func receive(completion: Subscribers.Completion<ErrorType>) {
        switch completion {
        case .finished:
            onCompleted(nil)
        case let .failure(error):
            onCompleted(error)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Subscriber {
    public func asSubscriberType() -> SubscriberType<Self.Input, Self.Failure> {
        .combine(subscriber: self)
    }

    public static func combine<CombineSubject: Subject>(subject: CombineSubject)
        -> SubscriberType<CombineSubject.Output, CombineSubject.Failure> {
        .init(
            onValue: { subject.send($0) },
            onCompleted: { error in
                subject.send(completion:
                    error.map(Subscribers.Completion<CombineSubject.Failure>.failure) ?? .finished
                )
            },
            onSubscribe: { subscription in
                subject.send(subscription: subscription.asCancellable())
            }
        )
    }

    public static func combine<CombineSubscriber: Subscriber>(subscriber: CombineSubscriber)
        -> SubscriberType<CombineSubscriber.Input, CombineSubscriber.Failure> {
        .init(
            onValue: { _ = subscriber.receive($0) },
            onCompleted: { error in
                subscriber.receive(completion:
                    error.map(Subscribers.Completion<CombineSubscriber.Failure>.failure) ?? .finished
                )
            },
            onSubscribe: { subscription in
                subscriber.receive(subscription: subscription.asCancellable())
            }
        )
    }

    public static func combine<Input, Failure>(onValue: ((Input) -> Void)? = nil, onCompleted: ((Failure?) -> Void)? = nil)
        -> SubscriberType<Input, Failure> {
        Subscribers.Sink<Input, Failure>(
            receiveCompletion: { completion in
                switch completion {
                case let .failure(error): onCompleted?(error)
                case .finished: onCompleted?(nil)
                }
            },
            receiveValue: onValue ?? { _ in }
        ).asSubscriberType()
    }
}
#endif
