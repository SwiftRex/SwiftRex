#if canImport(ReactiveSwift)
import ReactiveSwift

extension SignalProducer {
    func subscribe(onSuccess: @escaping (Value) -> Void,
                   onFailure: @escaping (Error) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        subscriptionOwner.inner += startWithResult { result in
            switch result {
            case let .success(value): onSuccess(value)
            case let .failure(error): onFailure(error)
            }
        }
    }
}
#endif
