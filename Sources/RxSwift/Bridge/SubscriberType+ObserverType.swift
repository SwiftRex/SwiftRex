import Foundation
import RxSwift
import SwiftRex

extension SubscriberType: ObserverType where ErrorType == Error {
    public func on(_ event: Event<Element>) {
        switch event {
        case let .next(value):
            onValue(value)
        case let .error(error):
            onCompleted(error)
        case .completed:
            onCompleted(nil)
        }
    }
}

extension ObserverType {
    public func asSubscriber() -> SubscriberType<Element, Error> {
        return SubscriberType<Element, Error>(
            onValue: { value in
                self.onNext(value)
            },
            onCompleted: { error in
                if let error = error {
                    self.onError(error)
                } else {
                    self.onCompleted()
                }
            }
        )
    }
}
