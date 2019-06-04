#if canImport(Combine)
import Combine

extension CurrentValueSubject {
    var currentValue: Output {
        return value
    }

    func modify(_ action: (inout Output) -> Void) {
        let mutation: ((inout Output) -> Void) -> Void = { [unowned self] action in
            var mutableState = self.currentValue
            action(&mutableState)
            self.value = mutableState
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
    return CurrentValueSubject(initialValue)
}
#endif
