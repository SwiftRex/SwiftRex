import ReactiveSwift

extension SignalProducer {
    func subscribe(onSuccess: @escaping (Value) -> Void,
                   onFailure: @escaping (Error) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        subscriptionOwner.inner += startWithResult { result in
            result.analysis(ifSuccess: onSuccess, ifFailure: onFailure)
        }
    }
}
