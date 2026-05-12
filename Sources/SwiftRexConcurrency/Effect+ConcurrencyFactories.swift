import SwiftRex

// MARK: - Async/await factories for Effect
//
// These factories require Swift Concurrency (async/await, Task, CheckedContinuation).
// They live in SwiftRex.Concurrency so the core SwiftRex target has no concurrency dependency.

extension Effect {
    /// Callback-based async work (URLSession, GCD, etc.).
    ///
    /// The `work` closure receives a `FutureCompleter`; call `completer.complete(action)` exactly
    /// once. `FutureCompleter` is `~Copyable` and `complete` is `consuming` — calling it twice
    /// is a **compile-time error**. Dropping the completer without calling `complete` resolves
    /// the future with no action.
    ///
    /// Cancellation is checked before starting work, while the callback is pending, and after
    /// the callback fires.
    public static func future(
        _ work: @escaping @Sendable (consuming FutureCompleter<Action>) -> Void,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    let box = FutureContinuationBox<Action>()
                    let result: Action? = await withTaskCancellationHandler {
                        await withCheckedContinuation { continuation in
                            box.store(continuation)
                            if Task.isCancelled {
                                box.cancel()
                            } else {
                                work(FutureCompleter(box))
                            }
                        }
                    } onCancel: {
                        box.cancel()
                    }
                    guard let action = result, !Task.isCancelled else { return }
                    send(DispatchedAction(action, dispatcher: source))
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }

    /// Async function that produces an optional action. The call site is captured as source.
    ///
    /// Returning `nil` dispatches nothing. The `Task` is cancelled when the `SubscriptionToken`
    /// is cancelled.
    public static func task(
        _ work: @escaping @Sendable () async -> Action?,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send in
                let t = Task {
                    guard let action = await work() else { return }
                    send(DispatchedAction(action, dispatcher: source))
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }

    /// Side effect with no resulting action. The `Task` is cancelled when the token is cancelled.
    public static func fireAndForget(_ work: @escaping @Sendable () async -> Void) -> Self {
        Effect(components: [
            Component(subscribe: { _ in
                let t = Task { await work() }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }
}
