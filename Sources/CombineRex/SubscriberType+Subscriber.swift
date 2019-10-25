#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension SubscriberType: Subscriber {
    public var combineIdentifier: CombineIdentifier {
        CombineIdentifier()
    }

    public func receive(subscription: Combine.Subscription) {
    }

    public func receive(_ input: Element) -> Subscribers.Demand {
        onValue(input)
        return .none
    }

    public func receive(completion: Subscribers.Completion<ErrorType>) {
        switch completion {
        case .finished:
            onCompleted(nil)
        case let .failure(error):
            onCompleted(error)
        }
    }
}

@available(iOS 13, watchOS 6, macOS 10.15, tvOS 13, *)
extension Subscriber {
    public func asSubscriberType() -> SubscriberType<Self.Input, Self.Failure> {
        .init(
            onValue: { value in
                _ = self.receive(value)
            },
            onCompleted: { error in
                if let error = error {
                    self.receive(completion: .failure(error))
                } else {
                    self.receive(completion: .finished)
                }
            }
        )
    }
}
#endif
