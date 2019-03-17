import ReactiveSwift
import enum Result.NoError
import struct Result.AnyError

public typealias ObservableSignal<T> = Signal<T, NoError>
public typealias ObservableFailableSignal<T> = Signal<T, AnyError>
public typealias ObservableSignalProducer<T> = SignalProducer<T, NoError>
public typealias ObservableFailableSignalProducer<T> = SignalProducer<T, AnyError>
public typealias SubscriptionOwner = ScopedDisposable<CompositeDisposable>
public typealias ObservableProperty = PropertyProtocol
public typealias ReactiveProperty<T> = MutableProperty<T>

func reactiveProperty<T>(initialValue: T) -> ReactiveProperty<T> {
    return MutableProperty(initialValue)
}

extension StateProvider {
    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    public typealias StateType = Value
    public typealias Error = Result.NoError
}
