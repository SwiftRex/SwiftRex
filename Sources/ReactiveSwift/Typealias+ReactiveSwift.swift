import struct ReactiveSwift.SignalProducer
import class ReactiveSwift.Signal
import protocol ReactiveSwift.PropertyProtocol
import class ReactiveSwift.ScopedDisposable
import class ReactiveSwift.CompositeDisposable
import class ReactiveSwift.MutableProperty

public typealias ObservableSignal<T> = Signal<T, Never>
public typealias FailableObservableSignal<T> = Signal<T, Error>
public typealias ObservableSignalProducer<T> = SignalProducer<T, Never>
public typealias FailableObservableSignalProducer<T> = SignalProducer<T, Error>
public typealias SubscriptionOwner = ScopedDisposable<CompositeDisposable>
public typealias ObservableProperty = PropertyProtocol
public typealias ReactiveProperty<T> = MutableProperty<T>

extension StateProvider {
    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    public typealias StateType = Value
}
