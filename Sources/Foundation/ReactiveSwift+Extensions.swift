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

extension SignalProducer {
    func subscribe(onSuccess: @escaping (T) -> Void,
                   onFailure: @escaping (E) -> Void,
                   disposeBy subscriptionOwner: SubscriptionOwner) {
        subscriptionOwner.inner += startWithResult { result in
            result.analysis(ifSuccess: onSuccess, ifFailure: onFailure)
        }
    }
}

extension StateProvider {
    /// The elements in the ObservableType sequence, which is expected to be the `StateType` (the app global state)
    public typealias StateType = Value
    public typealias Error = Result.NoError
}

extension StoreBase {
    public typealias Value = State

    /// The current value of the property.
    public var value: Value {
        return state.value
    }

    /// The values producer of the property.
    ///
    /// It produces a signal that sends the current state, followed by
    /// all state changes over time. It completes when the property
    /// has deinitialized, or has no further change.
    ///
    /// - note: If `self` is a composed property, the producer would be
    ///         bound to the lifetime of its sources.
    public var producer: SignalProducer<Value, NoError> {
        return state.producer
    }

    /// A signal that will send the property's changes over time. It
    /// completes when the property has deinitialized, or has no further
    /// change.
    ///
    /// - note: If `self` is a composed property, the signal would be
    ///         bound to the lifetime of its sources.
    public var signal: Signal<Value, NoError> {
        return state.signal
    }
}
