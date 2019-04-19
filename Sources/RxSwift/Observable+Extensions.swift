#if canImport(RxSwift)
import RxSwift

extension Observable {
    func subscribe(onSuccess: @escaping (Element) -> Void,
                   onFailure: @escaping (Error) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        subscribe(onNext: onSuccess, onError: onFailure).disposed(by: subscriptionOwner)
    }
}
#endif
