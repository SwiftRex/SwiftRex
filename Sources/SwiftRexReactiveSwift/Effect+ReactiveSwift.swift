@preconcurrency import ReactiveSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - SignalProducer (cold)
//
// Four overloads cover every common SignalProducer-to-Effect pattern:
//
//   Case A   SignalProducer<Action, Never>               .asEffect(scheduling:)
//            Value is already the Action — new ActionSource from call site.
//
//   Case A2  SignalProducer<DispatchedAction<A>, Never>  .asEffect(scheduling:)  — forwarding
//            Value is pre-sourced — dispatcher forwarded unchanged.
//
//   Case B   SignalProducer<V, Never>                    .asEffect(_ transform:scheduling:)
//            Infallible; user maps V → Action.
//
//   Case C   SignalProducer<V, E: Error>                 .asEffect(_ transform:scheduling:)
//            Failable; user maps Result<V, E> → Action.
//
// Lazy subscription model:
//   The producer is held in an `Unchecked` wrapper but is NOT started until the Store calls
//   the Effect's `subscribe` closure. Each subscription creates a `Lifetime`/`Token` pair;
//   the returned `SubscriptionToken` disposes the token which terminates the lifetime, ending
//   `take(during:)` on the producer.
//
// Signal<Value, Error> (hot) — always delegates to SignalProducer via `SignalProducer(self)`.

extension SignalProducer where Error == Never {
    /// Bridges a `SignalProducer<Action, Never>` to `Effect<Action>`.
    ///
    /// The call-site is captured as the ``ActionSource`` for every value the producer emits.
    /// Subscription is lazy — `startWithSignal` is only called when the Store runs the effect.
    /// Disposing the ``SubscriptionToken`` terminates the `Lifetime` used by `take(during:)`.
    ///
    /// ```swift
    /// let producer: SignalProducer<AppAction, Never> = …
    /// let effect: Effect<AppAction> = producer.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by this signal producer.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Value>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction($0, dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `SignalProducer<DispatchedAction<Action>, Never>`, forwarding dispatchers.
    ///
    /// Use when the producer already carries pre-sourced ``DispatchedAction`` values. No new
    /// ``ActionSource`` is created; the original dispatcher flows through unchanged.
    ///
    /// ```swift
    /// let producer: SignalProducer<DispatchedAction<AppAction>, Never> = …
    /// let effect: Effect<AppAction> = producer.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that forwards each ``DispatchedAction`` as-is.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Value == DispatchedAction<Action> {
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send($0) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `SignalProducer<Value, Never>` to `Effect<Action>` by mapping each value.
    ///
    /// Use when the producer's value type differs from the action type:
    ///
    /// ```swift
    /// enum AppAction { case didFetch(MyModel) }
    ///
    /// let producer: SignalProducer<MyModel, Never> = …
    /// let effect: Effect<AppAction> = producer.asEffect(AppAction.didFetch)
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Value` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by the mapped producer.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                    signal.observeCompleted { complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

extension SignalProducer where Error: Swift.Error {
    /// Bridges a failable `SignalProducer<Value, Error>` to `Effect<Action>` via a `Result` transform.
    ///
    /// This is the idiomatic ReactiveSwift bridge for producers that can fail. Each emitted value
    /// is mapped to `.success`; the terminating error (if any) is mapped to `.failure` and
    /// `complete` fires immediately after.
    ///
    /// Internally, the producer is mapped to `SignalProducer<Result<Value, Error>, Never>` using
    /// `flatMapError`, so `take(during:)` handles the lifetime cleanly in all cases.
    ///
    /// ```swift
    /// enum AppAction {
    ///     case didFetch(Result<MyModel, APIError>)
    /// }
    ///
    /// // Producer<MyModel, APIError> bridges directly using the enum case as transform
    /// apiProducer.asEffect(AppAction.didFetch)
    /// // Each model → .didFetch(.success(model))
    /// // API error  → .didFetch(.failure(error)) then complete
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Result<Value, Error>` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that handles both values and producer failures.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let (lifetime, token) = Lifetime.make()
                p.value
                    .map { Result<Value, Error>.success($0) }
                    .flatMapError { SignalProducer<Result<Value, Error>, Never>(value: .failure($0)) }
                    .take(during: lifetime)
                    .startWithSignal { signal, _ in
                        signal.observeValues { send(DispatchedAction(transform($0), dispatcher: source)) }
                        signal.observeCompleted { complete() }
                    }
                return SubscriptionToken { token.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Signal (hot) — delegates to SignalProducer

/// Bridges a hot `Signal<Value, Never>` to `Effect<Value>`.
///
/// `Signal` is hot in ReactiveSwift — it is already running before any subscriber attaches.
/// All `Signal` overloads here wrap `self` in a `SignalProducer` via `SignalProducer(self)`
/// and then delegate to the corresponding ``SignalProducer`` overload. The lazy-subscription
/// semantics apply to the `SignalProducer` wrapper; the underlying `Signal` remains hot.
///
/// For a full description of each overload's semantics, refer to the corresponding
/// `SignalProducer` documentation.
extension Signal where Error == Never {
    /// Bridges a hot `Signal<Action, Never>` to `Effect<Action>`.
    ///
    /// Wraps `self` in a `SignalProducer` and delegates to
    /// ``SignalProducer/asEffect(scheduling:file:function:line:)``.
    ///
    /// ```swift
    /// let signal: Signal<AppAction, Never> = …
    /// let effect: Effect<AppAction> = signal.asEffect()
    /// ```
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Value> where Value: Sendable {
        SignalProducer(self).asEffect(scheduling: scheduling, file: file, function: function, line: line)
    }

    /// Bridges a hot `Signal<DispatchedAction<Action>, Never>`, forwarding dispatchers.
    ///
    /// Wraps `self` in a `SignalProducer` and delegates to
    /// ``SignalProducer/asEffect(scheduling:)-dispatched``.
    ///
    /// ```swift
    /// let signal: Signal<DispatchedAction<AppAction>, Never> = …
    /// let effect: Effect<AppAction> = signal.asEffect()
    /// ```
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Value == DispatchedAction<Action> {
        SignalProducer(self).asEffect(scheduling: scheduling)
    }

    /// Bridges a hot `Signal<Value, Never>` to `Effect<Action>` by mapping each value.
    ///
    /// Wraps `self` in a `SignalProducer` and delegates to
    /// ``SignalProducer/asEffect(_:scheduling:file:function:line:)-infallible``.
    ///
    /// ```swift
    /// enum AppAction { case didFetch(MyModel) }
    ///
    /// let signal: Signal<MyModel, Never> = …
    /// let effect: Effect<AppAction> = signal.asEffect(AppAction.didFetch)
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, scheduling: scheduling, file: file, function: function, line: line)
    }
}

extension Signal where Error: Swift.Error {
    /// Bridges a hot `Signal<Value, Error>` to `Effect<Action>` via a `Result` transform.
    ///
    /// Wraps `self` in a `SignalProducer` and delegates to
    /// ``SignalProducer/asEffect(_:scheduling:file:function:line:)-failable``.
    ///
    /// ```swift
    /// enum AppAction { case didFetch(Result<MyModel, APIError>) }
    ///
    /// let signal: Signal<MyModel, APIError> = …
    /// let effect: Effect<AppAction> = signal.asEffect(AppAction.didFetch)
    /// ```
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Value, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        SignalProducer(self).asEffect(transform, scheduling: scheduling, file: file, function: function, line: line)
    }
}

// MARK: - Fire and forget (ReactiveSwift)

extension Effect {
    /// Creates an ``Effect`` that starts a `SignalProducer`, ignoring all values and errors.
    ///
    /// Use when a ReactiveSwift producer runs for its side effects alone, with no resulting
    /// action. A `Lifetime`/`Token` pair bounds the subscription; both `observeCompleted` and
    /// `observeFailed` trigger `complete`.
    ///
    /// Works naturally in point-free pipelines using `|>`:
    ///
    /// ```swift
    /// myProducer |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(cacheProducer)
    /// ```
    ///
    /// - Parameter sp: A `SignalProducer` to start for its side effects.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<V, E: Swift.Error>(_ sp: SignalProducer<V, E>) -> Self {
        let sp = Unchecked(value: sp)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let (lifetime, token) = Lifetime.make()
                sp.value.take(during: lifetime).startWithSignal { signal, _ in
                    signal.observeCompleted { complete() }
                    signal.observeFailed { _ in complete() }
                }
                return SubscriptionToken { token.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Creates an ``Effect`` that observes a hot `Signal`, ignoring all values and errors.
    ///
    /// Delegates to ``fireAndForget(_:)-SignalProducer`` via `SignalProducer(signal)`. Works in
    /// point-free pipelines using `|>`:
    ///
    /// ```swift
    /// mySignal |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(hotAnalyticsSignal)
    /// ```
    ///
    /// - Parameter signal: A hot `Signal` to observe for its side effects.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<V, E: Swift.Error>(_ signal: Signal<V, E>) -> Self {
        fireAndForget(SignalProducer(signal))
    }
}
