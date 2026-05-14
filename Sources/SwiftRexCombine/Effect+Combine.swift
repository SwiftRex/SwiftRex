#if canImport(Combine)
@preconcurrency import Combine
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Publisher → Effect bridges
//
// Four overloads cover every common Publisher-to-Effect pattern:
//
//   Case A   Publisher<Action, Never>               .asEffect(scheduling:)
//            Output is already the Action — new ActionSource from call site.
//
//   Case A2  Publisher<DispatchedAction<A>, Never>  .asEffect(scheduling:)
//            Output is pre-sourced — dispatcher forwarded unchanged, no new ActionSource.
//
//   Case B   Publisher<Output, Never>               .asEffect(_ transform:scheduling:)
//            Infallible; user maps Output → Action.
//
//   Case C   Publisher<Output, Failure: Error>      .asEffect(_ transform:scheduling:)
//            Failable; user maps Result<Output, Failure> → Action.
//
// Lazy subscription model:
//   The publisher is held in an `Unchecked` wrapper but is NOT subscribed until the Store
//   calls the Effect's `subscribe` closure. Each subscription creates a new `AnyCancellable`;
//   cancelling the returned `SubscriptionToken` calls `cancel()` on it.
//
// Completion: `complete()` fires on `.finished` or after the error action (Case C).
// Cancellation suppresses all further Combine callbacks including completion.

extension Publisher where Failure == Never {
    /// Bridges a `Publisher<Action, Never>` to `Effect<Action>`.
    ///
    /// The call-site (`#file`, `#function`, `#line`) is captured as the ``ActionSource`` for
    /// every element the publisher emits. Subscription is lazy — the publisher's `sink` is
    /// only called when the Store runs the effect.
    ///
    /// Use this overload when your publisher's `Output` is already the action type:
    ///
    /// ```swift
    /// let publisher: AnyPublisher<AppAction, Never> = …
    /// let effect: Effect<AppAction> = publisher.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by this publisher.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Output> where Output: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Output>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction($0, dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `Publisher<DispatchedAction<Action>, Never>` to `Effect<Action>`.
    ///
    /// The existing ``ActionSource`` inside each ``DispatchedAction`` is forwarded unchanged —
    /// no new ``ActionSource`` is created at the call site. Use this when the publisher already
    /// carries pre-sourced dispatched actions (e.g. from another middleware stage).
    ///
    /// ```swift
    /// let publisher: AnyPublisher<DispatchedAction<AppAction>, Never> = …
    /// let effect: Effect<AppAction> = publisher.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that forwards each ``DispatchedAction`` as-is.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Output == DispatchedAction<Action> {
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send($0) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a `Publisher<Output, Never>` to `Effect<Action>` by mapping each value.
    ///
    /// Use this overload when your publisher's `Output` differs from the action type and you
    /// need a transform function. The call-site is captured as the ``ActionSource``.
    ///
    /// ```swift
    /// enum AppAction { case didFetch(MyModel) }
    ///
    /// let publisher: AnyPublisher<MyModel, Never> = …
    /// let effect: Effect<AppAction> = publisher.asEffect(AppAction.didFetch)
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Output` value to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by the transformed publisher.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Output) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { send(DispatchedAction(transform($0), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }
}

extension Publisher where Failure: Error {
    /// Bridges a failable `Publisher<Output, Failure>` to `Effect<Action>` via a `Result` transform.
    ///
    /// This is the idiomatic Combine bridge for publishers that can fail. Each successfully
    /// emitted value is delivered as `.success`; the publisher's terminating error (if any) is
    /// delivered as `.failure` and then `complete` fires.
    ///
    /// Subscription is lazy — the `sink` is only attached when the Store runs the effect.
    /// Cancellation calls `AnyCancellable.cancel()` and suppresses all further callbacks.
    ///
    /// ```swift
    /// enum AppAction {
    ///     case didFetch(Result<MyModel, APIError>)
    /// }
    ///
    /// // Publisher<MyModel, APIError> bridges directly using the enum case as transform
    /// apiPublisher.asEffect(AppAction.didFetch)
    /// // Each model → .didFetch(.success(model))
    /// // API error  → .didFetch(.failure(error)) then complete
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Result<Output, Failure>` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that handles both values and publisher failures.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Output, Failure>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let p = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let c = p.value.sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        }
                        complete()
                    },
                    receiveValue: { send(DispatchedAction(transform(.success($0)), dispatcher: source)) }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Fire and forget (Publisher)

extension Effect {
    /// Creates an ``Effect`` that subscribes to a `Publisher`, ignoring all values and errors.
    ///
    /// Use when a Combine pipeline runs for its side effects alone, with no resulting action.
    /// The publisher is subscribed lazily when the Store runs the effect; `complete` fires
    /// when the publisher finishes (either `.finished` or `.failure`).
    ///
    /// Works naturally in point-free pipelines using `|>`:
    ///
    /// ```swift
    /// // Run an analytics publisher and discard the output
    /// myPublisher |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(cachePublisher)
    /// ```
    ///
    /// - Parameter p: Any `Publisher` to subscribe to for its side effects.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<P: Publisher>(_ p: P) -> Self {
        let p = Unchecked(value: p)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let c = p.value.sink(
                    receiveCompletion: { _ in complete() },
                    receiveValue: { _ in }
                )
                return SubscriptionToken { c.cancel() }
            }, scheduling: .immediately)
        ])
    }
}
#endif
