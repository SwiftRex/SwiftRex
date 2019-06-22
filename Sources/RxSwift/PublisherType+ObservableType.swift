import Foundation
import RxSwift
import SwiftRex

extension SwiftRex.PublisherType: ObservableConvertibleType, ObservableType {
    public func subscribe<Observer>(_ observer: Observer) -> Disposable
        where Observer: ObserverType, Element == Observer.Element {
        let subscriber: SwiftRex.SubscriberType<Element, ErrorType> = .init(
            onValue: observer.onNext,
            onCompleted: { error in
                if let error = error {
                    observer.onError(error)
                    return
                }
                observer.onCompleted()
            }
        )
        let subscription: SwiftRex.Subscription = self.subscribe(subscriber)
        return subscription.asDisposable()
    }
}

extension ObservableType {
    public func asPublisher() -> SwiftRex.PublisherType<Element, Error> {
        return .init { (subscriber: SwiftRex.SubscriberType<Element, Error>) -> SwiftRex.Subscription in
            DisposableSubscription(disposable: self.subscribe(subscriber.asObserver()))
        }
    }
}
