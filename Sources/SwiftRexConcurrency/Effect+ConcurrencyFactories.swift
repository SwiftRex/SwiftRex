import SwiftRex

// MARK: - Async/await factories for Effect

extension Effect {
    /// Callback-based async work. The `work` closure receives a `FutureCompleter`; call
    /// `completer.complete(action)` exactly once. Cancelled effects do NOT call `complete`.
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
                    guard !Task.isCancelled else { return }
                    if let action = result { send(DispatchedAction(action, dispatcher: source)) }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Async function that produces an optional action. Cancelled effects do NOT call `complete`.
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

    /// Side effect with no resulting action. Cancelled effects do NOT call `complete`.
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
