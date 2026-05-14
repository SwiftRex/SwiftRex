import SwiftRex

// MARK: - Async/await factories for Effect

extension Effect {
    /// Creates an ``Effect`` from a callback-based async operation using a ``FutureCompleter``.
    ///
    /// Use `future` when you have an existing callback-style API (delegate, completion handler,
    /// `URLSession.dataTask`, etc.) that you need to wrap as an `Effect`. The `work` closure
    /// receives a ``FutureCompleter``; you call `completer.complete(_:)` exactly once with the
    /// resulting action, then the effect completes.
    ///
    /// ``FutureCompleter`` is `~Copyable` — the compiler prevents duplication, so a second call
    /// to `complete` is a **compile-time error**. Dropping the completer without calling
    /// `complete` is safe: the `deinit` cancels the continuation, preventing a hung `Task`.
    ///
    /// Cancelled effects do **not** call `complete`.
    ///
    /// ```swift
    /// // Wrap a URLSession completion-handler call
    /// Effect<AppAction>.future { completer in
    ///     URLSession.shared.dataTask(with: request) { data, _, error in
    ///         let action: AppAction = data
    ///             .flatMap { try? JSONDecoder().decode(MyModel.self, from: $0) }
    ///             .map { AppAction.didFetch(.success($0)) }
    ///             ?? AppAction.didFetch(.failure(error ?? URLError(.unknown)))
    ///         completer.complete(action)
    ///     }.resume()
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - work: A `@Sendable` closure receiving a ``FutureCompleter``. Call
    ///     `completer.complete(action)` exactly once to resolve the effect.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that completes after `completer.complete` is called once.
    public static func future(
        _ work: @escaping @Sendable (consuming FutureCompleter<Action>) -> Void,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    let box = FutureContinuationBox<Action>()
                    let result: Action? = await withTaskCancellationHandler {
                        await withCheckedContinuation { continuation in
                            box.store(continuation)
                            if Task.isCancelled { box.cancel() } else { work(FutureCompleter(box)) }
                        }
                    } onCancel: { box.cancel()
                    }
                    guard !Task.isCancelled, let action = result else { return }
                    send(DispatchedAction(action, dispatcher: source))
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Creates an ``Effect`` from an `async` closure that produces an optional action.
    ///
    /// Use `task` when you have a simple `async` function that produces at most one action.
    /// If the closure returns `nil` the effect completes without dispatching anything — useful
    /// when a side effect (e.g. analytics) has no result to feed back to the store.
    ///
    /// Cancelled effects do **not** call `complete`.
    ///
    /// ```swift
    /// // Single fetch that maps to an AppAction
    /// Effect<AppAction>.task {
    ///     let model = try? await apiClient.fetchUser(id: userID)
    ///     return model.map(AppAction.didLoadUser)
    /// }
    ///
    /// // No action produced — side-effect only
    /// Effect<AppAction>.task {
    ///     await analytics.track(.screenViewed("Home"))
    ///     return nil
    /// }
    /// ```
    ///
    /// For failable work that must deliver an error action, prefer
    /// ``throwingTask(_:scheduling:_:file:function:line:)``.
    ///
    /// - Parameters:
    ///   - work: A `@Sendable` async closure returning `Action?`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that dispatches at most one action.
    public static func task(
        _ work: @escaping @Sendable () async -> Action?,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    let action = await work()
                    guard !Task.isCancelled else { return }
                    if let action { send(DispatchedAction(action, dispatcher: source)) }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Creates an ``Effect`` from an `async` closure that produces no action.
    ///
    /// Use `fireAndForget` when you need to run async work as a side effect but have nothing to
    /// dispatch back to the store — for example logging, analytics, cache warming, or prefetching.
    ///
    /// Cancelled effects do **not** call `complete`.
    ///
    /// ```swift
    /// Effect<AppAction>.fireAndForget {
    ///     await logger.log("User tapped sign in")
    /// }
    ///
    /// // Combine with a real effect using <>
    /// let combined = loginEffect <> Effect.fireAndForget { await analytics.track(.login) }
    /// ```
    ///
    /// - Parameters:
    ///   - work: A `@Sendable` async closure that performs the side effect.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget(
        _ work: @escaping @Sendable () async -> Void,
        scheduling: EffectScheduling = .immediately
    ) -> Self {
        Effect(components: [
            Component(subscribe: { _, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    await work()
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }
}
