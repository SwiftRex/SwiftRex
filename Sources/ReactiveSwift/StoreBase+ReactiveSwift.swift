import ReactiveSwift

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
    public var producer: SignalProducer<Value, Never> {
        return state.producer
    }

    /// A signal that will send the property's changes over time. It
    /// completes when the property has deinitialized, or has no further
    /// change.
    ///
    /// - note: If `self` is a composed property, the signal would be
    ///         bound to the lifetime of its sources.
    public var signal: Signal<Value, Never> {
        return state.signal
    }
}
