import Foundation
import ReactiveSwift
import SwiftRex

extension SignalProtocol {
    public func asPublisher() -> PublisherType<Value, Self.Error> {
        return PublisherType<Value, Self.Error> { subscriber in
            self.signal
                .observe(subscriber.asObserver())
                .map { $0.asSubscription() }
                ?? AnyDisposable().asSubscription()
        }
    }
}
