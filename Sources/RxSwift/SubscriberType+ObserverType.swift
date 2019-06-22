import Foundation
import RxSwift
import SwiftRex

extension SwiftRex.SubscriberType: ObserverType {
    public func on(_ event: Event<Element>) {
        switch event {
        case let .next(value):
            onValue(value)
        case let .error(error):
            switch error {
            case let error as ErrorType:
                onCompleted(error)
            default:
                fatalError(error.localizedDescription)
            }
        case .completed:
            onCompleted(nil)
        }
    }
}

extension ObserverType {
    public func asSubscriber() -> SwiftRex.SubscriberType<Element, Error> {
        return SwiftRex.SubscriberType<Element, Error>(
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
