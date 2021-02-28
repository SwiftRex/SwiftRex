import CombineX
import CXFoundation
import Foundation
import SwiftRex

extension SubscriberType: CombineX.Subscriber {
    public var combineIdentifier: CombineIdentifier {
        CombineIdentifier()
    }

    public func receive(subscription: CombineX.Subscription) {
        onSubscribe(subscription.asSubscriptionType())
    }

    public func receive(_ input: Element) -> CombineX.Subscribers.Demand {
        onValue(input)
        return .none
    }

    public func receive(completion: CombineX.Subscribers.Completion<ErrorType>) {
        switch completion {
        case .finished:
            onCompleted(nil)
        case let .failure(error):
            onCompleted(error)
        }
    }
}

extension CombineX.Subscriber {
    public func asSubscriberType() -> SubscriberType<Self.Input, Self.Failure> {
        .combineX(subscriber: self)
    }

    public static func combineX<CombineSubject: CombineX.Subject>(subject: CombineSubject)
        -> SubscriberType<CombineSubject.Output, CombineSubject.Failure> {
        .init(
            onValue: { subject.send($0) },
            onCompleted: { error in
                subject.send(completion:
                    error.map(CombineX.Subscribers.Completion<CombineSubject.Failure>.failure) ?? .finished
                )
            },
            onSubscribe: { subscription in
                subject.send(subscription: subscription.asCancellable())
            }
        )
    }

    public static func combineX<CombineSubscriber: CombineX.Subscriber>(subscriber: CombineSubscriber)
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

    public static func combineX<Input, Failure>(onValue: ((Input) -> Void)? = nil, onCompleted: ((Failure?) -> Void)? = nil)
        -> SubscriberType<Input, Failure> {
        CombineX.Subscribers.Sink<Input, Failure>(
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
