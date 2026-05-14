@preconcurrency import RxSwift
import SwiftRex

private struct Unchecked<T>: @unchecked Sendable { let value: T }

// MARK: - Infallible (RxSwift 6+)
//
// `Infallible<Element>` cannot error — equivalent to Combine's `Publisher<E, Never>`.
//
// Lazy subscription model:
//   The observable is held in an `Unchecked` wrapper but is NOT subscribed until the Store
//   calls the Effect's `subscribe` closure. Each subscription creates a new `Disposable`;
//   cancelling the returned `SubscriptionToken` calls `dispose()` on it.
//
// Three overloads mirror the Combine bridge:
//
//   Case A   Infallible<Action>               .asEffect(scheduling:)
//            Output is already the Action — new ActionSource from call site.
//
//   Case A2  Infallible<DispatchedAction<A>>  .asEffect(scheduling:)   — forwarding
//            Output is pre-sourced — dispatcher forwarded unchanged.
//
//   Case B   Infallible<Output>               .asEffect(_ transform:scheduling:)
//            User maps Output → Action.

extension InfallibleType {
    /// Bridges an `Infallible<Action>` to `Effect<Action>`.
    ///
    /// The call-site is captured as the ``ActionSource`` for every element. Subscription is
    /// lazy — observation only begins when the Store runs the effect. Disposing the returned
    /// ``SubscriptionToken`` calls `dispose()` on the underlying `Disposable`.
    ///
    /// ```swift
    /// let infallible: Infallible<AppAction> = …
    /// let effect: Effect<AppAction> = infallible.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by this infallible observable.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction($0, dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Infallible<DispatchedAction<Action>>`, forwarding the existing dispatcher.
    ///
    /// Use when the observable already carries pre-sourced ``DispatchedAction`` values. No new
    /// ``ActionSource`` is created; the original dispatcher flows through unchanged.
    ///
    /// ```swift
    /// let infallible: Infallible<DispatchedAction<AppAction>> = …
    /// let effect: Effect<AppAction> = infallible.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that forwards each ``DispatchedAction`` as-is.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Element == DispatchedAction<Action> {
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send($0) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Infallible<Output>` to `Effect<Action>` by mapping each element.
    ///
    /// Use when the infallible's element type differs from the action type:
    ///
    /// ```swift
    /// enum AppAction { case didFetch(MyModel) }
    ///
    /// let infallible: Infallible<MyModel> = …
    /// let effect: Effect<AppAction> = infallible.asEffect(AppAction.didFetch)
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Element` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by the mapped infallible.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Observable (failable)
//
// Four overloads cover every common Observable-to-Effect pattern:
//
//   Case A   Observable<Action>               .asEffect(scheduling:)           — errors discarded
//   Case A2  Observable<DispatchedAction<A>>  .asEffect(scheduling:)           — forwarding
//   Case B   Observable<Output>               .asEffect(_ transform:scheduling:) — errors discarded
//   Case C   Observable<Output>               .asEffect(_ transform:scheduling:) — Result
//
// Error handling in Cases A, A2, B:
//   onError fires `complete()` immediately — the error is silently consumed. Use Case C when
//   you need to feed errors back into the store.

extension ObservableType {
    /// Bridges an `Observable<Action>` to `Effect<Action>`. Errors are silently discarded.
    ///
    /// Subscription is lazy — observation begins when the Store runs the effect. Each element
    /// dispatches an action tagged with the call-site ``ActionSource``. If the observable
    /// errors, `complete` fires immediately and the error is discarded.
    ///
    /// Use ``asEffect(_:scheduling:file:function:line:)-Result`` (the `Result` overload) when
    /// you need to deliver errors to the store.
    ///
    /// ```swift
    /// let observable: Observable<AppAction> = …
    /// let effect: Effect<AppAction> = observable.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by this observable.
    public func asEffect(
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Element> where Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Element>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction($0, dispatcher: source)) },
                    onError: { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<DispatchedAction<Action>>`, forwarding the existing dispatcher.
    ///
    /// The original ``ActionSource`` inside each ``DispatchedAction`` flows through unchanged —
    /// no new ``ActionSource`` is created. Errors are silently discarded and trigger `complete`.
    ///
    /// ```swift
    /// let observable: Observable<DispatchedAction<AppAction>> = …
    /// let effect: Effect<AppAction> = observable.asEffect()
    /// ```
    ///
    /// - Parameters:
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that forwards each ``DispatchedAction`` as-is.
    public func asEffect<Action: Sendable>(
        scheduling: EffectScheduling = .immediately
    ) -> Effect<Action> where Element == DispatchedAction<Action> {
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send($0) },
                    onError: { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` by mapping each element.
    ///
    /// Errors are silently discarded and trigger `complete` immediately. Use the `Result`
    /// overload when errors must be fed back to the store.
    ///
    /// ```swift
    /// enum AppAction { case didFetch(MyModel) }
    ///
    /// let observable: Observable<MyModel> = …
    /// let effect: Effect<AppAction> = observable.asEffect(AppAction.didFetch)
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Element` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` backed by the mapped observable.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction(transform($0), dispatcher: source)) },
                    onError: { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `Observable<Output>` to `Effect<Action>` via a `Result` transform.
    ///
    /// This is the idiomatic RxSwift bridge for failable observables. Each emitted element is
    /// delivered as `.success`; if the observable errors, the error is delivered as `.failure`
    /// and `complete` fires immediately after.
    ///
    /// ```swift
    /// enum AppAction {
    ///     case didFetch(Result<MyModel, Error>)
    /// }
    ///
    /// apiObservable.asEffect(AppAction.didFetch)
    /// // Each model  → .didFetch(.success(model))
    /// // Observable error → .didFetch(.failure(error)) then complete
    /// ```
    ///
    /// - Parameters:
    ///   - transform: Maps each `Result<Element, Error>` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that handles both values and observable errors.
    public func asEffect<Action: Sendable>(
        _ transform: @escaping @Sendable (Result<Element, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<Action> {
        let source = ActionSource(file: file, function: function, line: line)
        let o = Unchecked(value: self)
        return Effect(components: [
            Effect<Action>.Component(subscribe: { send, complete in
                let d = o.value.subscribe(
                    onNext: { send(DispatchedAction(transform(.success($0)), dispatcher: source)) },
                    onError: { error in
                        send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                        complete()
                    },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Fire and forget (RxSwift)

extension Effect {
    /// Creates an ``Effect`` that subscribes to an `Observable`, ignoring all elements and errors.
    ///
    /// Use when an RxSwift observable runs for its side effects alone, with no resulting action.
    /// The observable is subscribed lazily when the Store runs the effect. Both `onError` and
    /// `onCompleted` trigger `complete`, so the effect always terminates.
    ///
    /// Works naturally in point-free pipelines using `|>`:
    ///
    /// ```swift
    /// myObservable |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(analyticsObservable)
    /// ```
    ///
    /// - Parameter o: Any `ObservableType` to subscribe to for its side effects.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<O: ObservableType>(_ o: O) -> Self {
        let o = Unchecked(value: o)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let d = o.value.subscribe(
                    onNext: { _ in },
                    onError: { _ in complete() },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }

    /// Creates an ``Effect`` that subscribes to an `Infallible`, ignoring all elements.
    ///
    /// The infallible cannot error so the effect simply waits for `onCompleted`. Works
    /// naturally in point-free pipelines using `|>`:
    ///
    /// ```swift
    /// myInfallible |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(loggerInfallible)
    /// ```
    ///
    /// - Parameter i: Any `InfallibleType` to subscribe to for its side effects.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<I: InfallibleType>(_ i: I) -> Self {
        let i = Unchecked(value: i)
        return Effect(components: [
            Component(subscribe: { _, complete in
                let d = i.value.subscribe(
                    onNext: { _ in },
                    onCompleted: { complete() }
                )
                return SubscriptionToken { d.dispose() }
            }, scheduling: .immediately)
        ])
    }
}
