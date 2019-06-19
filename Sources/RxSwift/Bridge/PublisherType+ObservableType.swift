import Foundation
import RxSwift
import SwiftRex

extension PublisherType: ObservableConvertibleType, ObservableType where ErrorType == Error {
    public func subscribe<Observer>(_ observer: Observer) -> Disposable where Observer: ObserverType, Element == Observer.Element {
        let subscriber: SubscriberType<Element, Error> = observer.asSubscriber()
        let subscription: Subscription = subscribe(subscriber)
        return subscription.asDisposable()
    }
}

extension ObservableType {
    public func asPublisher() -> PublisherType<Element, Error> {
        return PublisherType<Element, Error> { subscriber in
            DisposableSubscription(disposable: self.subscribe(subscriber.asObserver()))
        }
    }
}
