import Foundation
import ReactiveSwift
import SwiftRex

extension SignalProtocol {
    public func asPublisherType() -> PublisherType<Value, Self.Error> {
        .init { subscriber in
            self.signal
                .observe(subscriber.asObserver())
                .map { $0.asSubscriptionType() }
                ?? AnyDisposable().asSubscriptionType()
        }
    }
}
