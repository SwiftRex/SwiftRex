#if canImport(RxSwift)
import Foundation
import RxSwift

extension BehaviorSubject {
    var currentValue: E {
        return try! value()
    }

    func modify(_ action: (inout E) -> Void) {
        let mutation: ((inout E) -> Void) -> Void = { [unowned self] action in
            var mutableState = self.currentValue
            action(&mutableState)
            self.onNext(mutableState)
        }

        if Thread.isMainThread {
            mutation(action)
        } else {
            DispatchQueue.main.sync {
                mutation(action)
            }
        }
    }
}

func reactiveProperty<T>(initialValue: T) -> ReactiveProperty<T> {
    return BehaviorSubject(value: initialValue)
}
#endif
