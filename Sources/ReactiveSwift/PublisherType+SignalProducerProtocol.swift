import Foundation
import ReactiveSwift
import SwiftRex

extension PublisherType: SignalProducerProtocol, SignalProducerConvertible {
    public var producer: SignalProducer<Element, ErrorType> {
        return SignalProducer<Element, ErrorType> { observer, lifetime in
            let subscription = self.subscribe(SubscriberType(
                onValue: { value in
                    guard !lifetime.hasEnded else { return }
                    observer.send(value: value)
                },
                onCompleted: { error in
                    guard !lifetime.hasEnded else { return }
                    if let error = error {
                        observer.send(error: error)
                    } else {
                        observer.sendCompleted()
                    }
                }
            ))
            lifetime.observeEnded(subscription.unsubscribe)
        }
    }
}

extension SignalProducerProtocol {
    public func asPublisher() -> PublisherType<Value, Self.Error> {
        return PublisherType<Value, Self.Error> { subscriber in
            DisposableSubscription(disposable: self.producer.start(subscriber.asObserver()))
        }
    }
}
