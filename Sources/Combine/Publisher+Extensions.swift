#if canImport(Combine)
import Combine

extension Publisher {
    func subscribe(onSuccess: @escaping (Output) -> Void,
                   onFailure: @escaping (Error) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        sink(
            receiveCompletion: { completion in
                switch completion {
                case let .failure(error): onFailure(error)
                default: break
                }
            },
            receiveValue: onSuccess
        ).disposed(by: subscriptionOwner)
    }
}
#endif
