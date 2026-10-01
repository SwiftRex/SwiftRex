// SPDX-License-Identifier: Apache-2.0

/// A store's state over time — the only way to follow a store.
///
/// Stores are **declarative**: there is no `state` to read at a given moment, only a stream to observe.
/// A `StateStream` is a *description*: creating one, or mapping it, subscribes to nothing. Observing it does:
///
/// ```swift
/// let token = store.stateStream.observe { state in
///     render(state) // called right away with the current state, then after every change
/// }
/// ```
///
/// - **The current value first, synchronously.** ``observe(_:)`` calls you with the current state *during*
///   the call, then once after every change. Everything happens on the main actor, so a chain of stores
///   following each other updates within the same run-loop turn (and the same SwiftUI transaction —
///   `withAnimation { store.dispatch(…) }` animates).
/// - **After the fact.** Values describe changes that already happened. The "about to change" moment SwiftUI
///   needs lives in the view layer, which keeps its own snapshot.
/// - **Operators** — ``map(_:)`` and ``removeDuplicates()`` / ``removeDuplicates(by:)`` — build new
///   descriptions; each observer of the result runs them for itself.
/// - It is also an `AsyncSequence` (iterate it from the main actor), and the bridge products make it a Combine
///   `Publisher`, an RxSwift `ObservableType`, a ReactiveSwift `SignalProducerConvertible`, … — see each bridge.
@MainActor
public struct StateStream<State: Sendable> {
    private let start: @MainActor (@escaping @MainActor (State) -> Void) -> (current: State, token: UISubscriptionToken)

    /// A stream from its subscription function: register `onChange` for every **future** state and return the
    /// **current** state together with a token that unregisters it. Returning the current value (rather than
    /// promising to call back with it) is what makes "the current value first, synchronously" hold by
    /// construction.
    public init(
        _ subscribe: @escaping @MainActor (_ onChange: @escaping @MainActor (State) -> Void) -> (current: State, token: UISubscriptionToken)
    ) {
        start = subscribe
    }

    /// Starts following the stream: `onValue` receives the current state immediately (before this returns),
    /// then every new state. Retain the token; releasing it stops the observation.
    public func observe(_ onValue: @escaping @MainActor (State) -> Void) -> UISubscriptionToken {
        let (current, token) = start(onValue)
        onValue(current)
        return token
    }

    /// Starts following the stream, returning the current state instead of calling back with it: `onChange`
    /// receives only the states that come after. For code that needs the current value in hand before anything
    /// else — seeding a snapshot, a `CurrentValueSubject`, a replaying bridge.
    public func subscribe(onChange: @escaping @MainActor (State) -> Void) -> (current: State, token: UISubscriptionToken) {
        start(onChange)
    }

    // MARK: - Operators

    /// The stream of `transform(state)`.
    public func map<T: Sendable>(_ transform: @escaping (State) -> T) -> StateStream<T> {
        let start = self.start
        return StateStream<T> { onChange in
            let (current, token) = start { onChange(transform($0)) }
            return (transform(current), token)
        }
    }

    /// `map`, for a main-actor transform (a projection's `state` closure).
    func mapIsolated<T: Sendable>(_ transform: @escaping @MainActor (State) -> T) -> StateStream<T> {
        let start = self.start
        return StateStream<T> { onChange in
            let (current, token) = start { onChange(transform($0)) }
            return (transform(current), token)
        }
    }

    /// Skips a value when `areDuplicates(previous, next)` is `true`. The first value always passes.
    public func removeDuplicates(by areDuplicates: @escaping (State, State) -> Bool) -> StateStream<State> {
        let start = self.start
        return StateStream { onChange in
            let last = LastValue<State>()
            let (current, token) = start { new in
                guard let previous = last.value, !areDuplicates(previous, new) else { return }
                last.value = new
                onChange(new)
            }
            last.value = current
            return (current, token)
        }
    }

    /// Skips a value equal (`==`) to the previous one.
    public func removeDuplicates() -> StateStream<State> where State: Equatable {
        removeDuplicates(by: ==)
    }
}

extension StateStream {
    /// The wrapped value while `.some`, and the **last present one** once `nil` — seeded with `fallback` when the
    /// stream starts out `nil`. Each observer remembers its own last value. Plumbing behind ``StoreOptionalFocus``: a child
    /// screen can outlive its state for the frames of a dismissal and must keep showing what it last showed.
    package func holdingLastPresent<Wrapped: Sendable>(fallback: Wrapped) -> StateStream<Wrapped> where State == Wrapped? {
        let start = self.start
        return StateStream<Wrapped> { onChange in
            let last = LastValue<Wrapped>()
            let (current, token) = start { new in
                let value = new ?? last.value ?? fallback
                last.value = value
                onChange(value)
            }
            let seed = current ?? fallback
            last.value = seed
            return (seed, token)
        }
    }
}

// The previous value seen by one observer of `removeDuplicates` / `holdingLastPresent`.
@MainActor
private final class LastValue<Value> {
    var value: Value?
}
