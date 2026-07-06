// SPDX-License-Identifier: Apache-2.0

import SwiftRex

// MARK: - AsyncSequence → Effect

extension Effect {
    /// Bridges an `AsyncSequence` to `Effect<Action>`, mapping each element to an action.
    ///
    /// Subscribes lazily: the sequence is only iterated when the Store runs the effect.
    /// Cancellation stops the iteration at the next `guard !Task.isCancelled` checkpoint,
    /// without calling `complete`. When the sequence finishes normally `complete` fires.
    ///
    /// ```swift
    /// // Map each element of an async stream to an AppAction
    /// Effect<AppAction>.asyncSequence(liveDataFeed, AppAction.didReceive)
    ///
    /// // Equivalent point-free style
    /// Effect<AppAction>.asyncSequence(liveDataFeed) { .didReceive($0) }
    /// ```
    ///
    /// - Parameters:
    ///   - sequence: A `Sendable` `AsyncSequence` whose elements drive the effect.
    ///   - transform: Maps each element to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that dispatches one action per element.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (S.Element) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
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

    /// Bridges a failable `AsyncSequence` to `Effect<Action>` via a `Result` transform.
    ///
    /// Each element is delivered as `.success`; if the sequence throws, the error is
    /// delivered as `.failure` and `complete` fires immediately after. Cancellation stops
    /// iteration without calling `complete`.
    ///
    /// This overload is particularly useful when the sequence can fail and you need to
    /// feed the error back into the store's action type:
    ///
    /// ```swift
    /// enum AppAction {
    ///     case didReceive(Result<DataPacket, StreamError>)
    /// }
    ///
    /// Effect<AppAction>.asyncSequence(
    ///     liveDataFeed,
    ///     AppAction.didReceive
    /// )
    /// // Each packet → .didReceive(.success(packet))
    /// // Stream error → .didReceive(.failure(error))
    /// ```
    ///
    /// - Parameters:
    ///   - sequence: A `Sendable` `AsyncSequence` that can throw.
    ///   - transform: Maps each `Result<Element, Error>` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that handles both values and errors.
    public static func asyncSequence<S: AsyncSequence & Sendable>(
        _ sequence: S,
        _ transform: @escaping @Sendable (Result<S.Element, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
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
    ///
    /// Use this overload when your sequence already produces ``DispatchedAction`` values
    /// (e.g. a sequence created by another part of the middleware pipeline) and you want
    /// the original dispatcher provenance to flow through unchanged.
    ///
    /// ```swift
    /// // The sequence owns dispatch provenance — no new ActionSource is created
    /// Effect<AppAction>.asyncSequence(preSourcedStream)
    /// ```
    ///
    /// - Parameters:
    ///   - sequence: A `Sendable` `AsyncSequence` of ``DispatchedAction`` values.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    /// - Returns: An `Effect<Action>` that forwards each ``DispatchedAction`` as-is.
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

// MARK: - Throwing async task → Effect

extension Effect {
    /// Creates an ``Effect`` from a `throws`-marked async closure, wrapping the outcome in `Result`.
    ///
    /// This is the idiomatic way to bridge a throwing `async` function when you want to feed
    /// both success and failure into a single action case. The closure is placed last so you
    /// can use trailing-closure syntax.
    ///
    /// ```swift
    /// enum AppAction {
    ///     case didFetch(Result<MyModel, Error>)
    /// }
    ///
    /// Effect<AppAction>.throwingTask(AppAction.didFetch) {
    ///     try await api.search(query)
    /// }
    /// // Success → .didFetch(.success(model))
    /// // Thrown error → .didFetch(.failure(error))
    /// ```
    ///
    /// Cancelled effects do **not** call `complete`.
    ///
    /// - Parameters:
    ///   - transform: Maps the `Result<Success, Error>` to an `Action`.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to
    ///     ``EffectScheduling/immediately``.
    ///   - work: A `@Sendable` throwing async closure returning `Success`.
    ///   - file: Source file; captured automatically.
    ///   - function: Source function; captured automatically.
    ///   - line: Source line; captured automatically.
    /// - Returns: An `Effect<Action>` that dispatches exactly one action regardless of outcome.
    public static func throwingTask<Success: Sendable>(
        _ transform: @escaping @Sendable (Result<Success, Error>) -> Action,
        scheduling: EffectScheduling = .immediately,
        _ work: @escaping @Sendable () async throws -> Success,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
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

// MARK: - Fire and forget (AsyncSequence)

extension Effect {
    /// Creates an ``Effect`` that iterates an `AsyncSequence` to completion, ignoring all elements and errors.
    ///
    /// Use when you need a sequence to run for its side effects alone, with no resulting action.
    /// All elements are silently consumed; any thrown errors are silently discarded via `try?`.
    /// Works well in point-free pipelines using `|>`:
    ///
    /// ```swift
    /// // Run a side-effecting stream and discard every element
    /// myAsyncSequence |> Effect.fireAndForget
    ///
    /// // Or call directly
    /// Effect<AppAction>.fireAndForget(cacheWarmupSequence)
    /// ```
    ///
    /// - Parameter sequence: A `Sendable` `AsyncSequence` to iterate.
    /// - Returns: An `Effect<Action>` that never dispatches an action.
    public static func fireAndForget<S: AsyncSequence & Sendable>(_ sequence: S) -> Self
    where S.Element: Sendable {
        Effect(components: [
            Component(subscribe: { _, complete in
                let t = Task {
                    guard !Task.isCancelled else { return }
                    _ = try? await { for try await _ in sequence {} }()
                    guard !Task.isCancelled else { return }
                    complete()
                }
                return SubscriptionToken { t.cancel() }
            }, scheduling: .immediately)
        ])
    }
}
