import RxSwift
import SwiftRex

func observable<T>(of type: T.Type, error: Error) -> Observable<T> {
    return Observable.error(error)
}

func observable<T>(of values: T...) -> Observable<T> {
    return Observable.create { observer in
        values.forEach(observer.onNext)
        observer.onCompleted()
        return Disposables.create()
    }
}

extension SubscriptionOwner {
    static func new() -> SubscriptionOwner {
        return DisposeBag()
    }
}
