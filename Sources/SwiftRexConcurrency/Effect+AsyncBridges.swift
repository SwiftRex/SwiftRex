import CoreFP
import SwiftRex

// MARK: - AsyncSequence → Effect

extension Effect {
    /// Bridges any `AsyncSequence` to `Effect<Action>`. Each element is mapped to an action.
    ///
    /// The underlying `Task` is cancelled when the `SubscriptionToken` is cancelled.
    /// `complete()` fires when the sequence ends naturally; it is NOT called on cancellation.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (S.Element) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self where S.Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    for try await element in sequence {
                        guard !Task.isCancelled else { return }
                        send(DispatchedAction(transform(element), dispatcher: source))
                    }
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }

    /// Bridges a failable `AsyncSequence` to `Effect<Action>` via Result transform.
    ///
    /// Each element arrives as `.success`; a thrown error arrives as `.failure` and is
    /// dispatched before `complete()` fires.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (Result<S.Element, Error>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self where S.Element: Sendable {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    do {
                        for try await element in sequence {
                            guard !Task.isCancelled else { return }
                            send(DispatchedAction(transform(.success(element)), dispatcher: source))
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                    }
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - DeferredTask → Effect

extension Effect {
    /// Runs a `DeferredTask<Action>` and dispatches the result as an action.
    ///
    /// `DeferredTask` starts executing only when the Store calls subscribe — it is fully lazy.
    /// `complete()` fires after the task finishes, unless cancelled.
    public static func deferredTask(
        _ task: DeferredTask<Action>,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        Effect.task({ await task.run() }, file: file, function: function, line: line)
    }

    /// Runs a `DeferredTask<Result<Success, Failure>>` and maps the result to an action.
    public static func deferredTask<Success: Sendable, Failure: Error>(
        _ task: DeferredTask<Result<Success, Failure>>,
        _ transform: @escaping @Sendable (Result<Success, Failure>) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        Effect.task({ transform(await task.run()) }, file: file, function: function, line: line)
    }

    /// Runs a throwing async closure, wrapping success/failure in `Result<Success, Error>`,
    /// then maps to an action.
    ///
    /// ```swift
    /// Effect.throwingTask(AppAction.didFetch) { try await api.search(query) }
    /// // enum AppAction { case didFetch(Result<MyModel, Error>) }
    /// ```
    public static func throwingTask<Success: Sendable>(
        _ transform: @escaping @Sendable (Result<Success, Error>) -> Action,
        _ work: @escaping @Sendable () async throws -> Success,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    do {
                        let value = try await work()
                        guard !Task.isCancelled else { return }
                        send(DispatchedAction(transform(.success(value)), dispatcher: source))
                    } catch {
                        guard !Task.isCancelled else { return }
                        send(DispatchedAction(transform(.failure(error)), dispatcher: source))
                    }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - DeferredStream → Effect

extension Effect {
    /// Bridges a `DeferredStream<Element>` to `Effect<Action>` by mapping each element.
    ///
    /// `DeferredStream`'s factory runs only when the Store calls subscribe.
    /// `complete()` fires when the stream ends naturally; it is NOT called on cancellation.
    public static func deferredStream<Element: Sendable>(
        _ stream: DeferredStream<Element>,
        _ transform: @escaping @Sendable (Element) -> Action,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        asyncSequence(stream, transform, file: file, function: function, line: line)
    }
}
