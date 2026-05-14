import CoreFP
import SwiftRex

// MARK: - AsyncSequence → Effect

extension Effect {
    /// Bridges an `AsyncSequence` to `Effect<Action>`, mapping each element to an action.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (S.Element) -> Action,
        scheduling: EffectScheduling = .immediately,
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
            }, scheduling: scheduling)
        ])
    }

    /// Bridges a failable `AsyncSequence` to `Effect<Action>` via Result transform.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (Result<S.Element, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
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
            }, scheduling: scheduling)
        ])
    }

    /// Bridges an `AsyncSequence<DispatchedAction<Action>>`, preserving existing dispatchers.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        scheduling: EffectScheduling = .immediately
    ) -> Self where S.Element == DispatchedAction<Action> {
        Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    for try await dispatched in sequence {
                        guard !Task.isCancelled else { return }
                        send(dispatched)
                    }
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - DeferredTask → Effect

extension Effect {
    /// Runs a `DeferredTask<Action>` and dispatches the result as an action.
    public static func deferredTask(
        _ task: DeferredTask<Action>,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        Effect.task({ await task.run() }, scheduling: scheduling, file: file, function: function, line: line)
    }

    /// Runs a `DeferredTask<Result<Success, Failure>>` and maps the result to an action.
    public static func deferredTask<Success: Sendable, Failure: Error>(
        _ task: DeferredTask<Result<Success, Failure>>,
        _ transform: @escaping @Sendable (Result<Success, Failure>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        Effect.task({ transform(await task.run()) }, scheduling: scheduling, file: file, function: function, line: line)
    }

    /// Runs a `DeferredTask<DispatchedAction<Action>>`, preserving the existing dispatcher.
    public static func deferredTask(
        _ task: DeferredTask<DispatchedAction<Action>>,
        scheduling: EffectScheduling = .immediately
    ) -> Self {
        Effect(components: [
            Component(subscribe: { send, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    let dispatched = await task.run()
                    guard !Task.isCancelled else { return }
                    send(dispatched)
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: scheduling)
        ])
    }

    /// Runs a throwing async closure, wrapping the result in `Result<Success, Error>`.
    ///
    /// ```swift
    /// Effect.throwingTask(AppAction.didFetch) { try await api.search(query) }
    /// ```
    public static func throwingTask<Success: Sendable>(
        _ transform: @escaping @Sendable (Result<Success, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
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
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - DeferredStream → Effect

extension Effect {
    /// Bridges a `DeferredStream<Element>` to `Effect<Action>` by mapping each element.
    public static func deferredStream<Element: Sendable>(
        _ stream: DeferredStream<Element>,
        _ transform: @escaping @Sendable (Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file, function: String = #function, line: UInt = #line
    ) -> Self {
        asyncSequence(stream, transform, scheduling: scheduling, file: file, function: function, line: line)
    }

    /// Bridges a `DeferredStream<DispatchedAction<Action>>`, preserving existing dispatchers.
    public static func deferredStream(
        _ stream: DeferredStream<DispatchedAction<Action>>,
        scheduling: EffectScheduling = .immediately
    ) -> Self {
        asyncSequence(stream, scheduling: scheduling)
    }
}

// MARK: - Fire and forget (AsyncSequence)

extension Effect {
    /// Iterates `sequence` to completion, ignoring all elements and errors.
    /// Use with `|>`: `myAsyncSequence |> Effect.fireAndForget`.
    public static func fireAndForget<S: AsyncSequence & Sendable>(_ sequence: S) -> Self
    where S.Element: Sendable {
        Effect(components: [
            Component(subscribe: { _, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    _ = try? await { for try await _ in sequence { } }()
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }
}

