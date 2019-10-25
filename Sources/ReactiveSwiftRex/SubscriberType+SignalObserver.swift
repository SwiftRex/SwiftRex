import Foundation
import ReactiveSwift
import SwiftRex

extension SubscriberType {
    public func asObserver() -> Signal<Element, ErrorType>.Observer {
        .init(
            value: self.onValue,
            failed: { error in self.onCompleted(error) },
            completed: { self.onCompleted(nil) },
            interrupted: nil
        )
    }
}

extension Signal.Observer {
    public func asSubscriber() -> SubscriberType<Value, Error> {
        .init(
            onValue: { value in
                self.send(value: value)
            },
            onCompleted: { error in
                if let error = error {
                    self.send(error: error)
                } else {
                    self.sendCompleted()
                }
            }
        )
    }
}
