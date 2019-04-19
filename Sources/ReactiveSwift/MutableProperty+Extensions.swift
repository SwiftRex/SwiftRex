#if canImport(ReactiveSwift)
import ReactiveSwift

extension MutableProperty {
    var currentValue: Value {
        return value
    }
}

func reactiveProperty<T>(initialValue: T) -> ReactiveProperty<T> {
    return MutableProperty(initialValue)
}
#endif
