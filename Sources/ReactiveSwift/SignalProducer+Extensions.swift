import ReactiveSwift

extension SignalProducer {
    func subscribe(onSuccess: @escaping (T) -> Void,
                   onFailure: @escaping (E) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        subscriptionOwner.inner += startWithResult { result in
            result.analysis(ifSuccess: onSuccess, ifFailure: onFailure)
        }
    }
}
