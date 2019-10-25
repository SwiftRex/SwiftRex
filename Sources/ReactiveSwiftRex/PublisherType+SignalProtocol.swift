import Foundation
import ReactiveSwift
import SwiftRex

extension SignalProtocol {
    public func asPublisher() -> PublisherType<Value, Self.Error> {
        .init { subscriber in
            self.signal
                .observe(subscriber.asObserver())
                .map { $0.asSubscription() }
                ?? AnyDisposable().asSubscription()
        }
    }
}
