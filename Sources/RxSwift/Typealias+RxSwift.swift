import RxSwift

public typealias ObservableSignal<T> = Observable<T>
public typealias FailableObservableSignal<T> = Observable<T>
public typealias ObservableSignalProducer<T> = Observable<T>
public typealias FailableObservableSignalProducer<T> = Observable<T>
public typealias SubscriptionOwner = DisposeBag
public typealias ObservableProperty = ObservableType
public typealias ReactiveProperty<T> = BehaviorSubject<T>

func reactiveProperty<T>(initialValue: T) -> ReactiveProperty<T> {
    return BehaviorSubject(value: initialValue)
}

extension StateProvider {
    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    public typealias StateType = E
}
