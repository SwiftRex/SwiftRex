// MARK: - Convenience factories (raw Action — call site captured automatically)

extension Effect {
    /// Creates an effect that dispatches a single action and immediately signals completion.
    ///
    /// The call-site source location is captured automatically via default `#file`, `#function`,
    /// and `#line` parameters, so the dispatched action carries accurate provenance for logging
    /// and tracing. Use the ``DispatchedAction`` overload when you need to forward an existing
    /// source unchanged.
    ///
    /// ```swift
    /// // Dispatch .logout immediately after session expiry is detected
    /// return .produce { _ in
    ///     .just(.logout)
    /// }
    ///
    /// // Debounce a single action
    /// return .produce { _ in
    ///     .just(.refreshFeed, scheduling: .debounce(id: "refresh", delay: 1.0))
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - action: The raw action to dispatch.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to ``EffectScheduling/immediately``.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    /// - Returns: A single-component ``Effect`` that sends `action` then calls `complete`.
    public static func just(
        _ action: Action,
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            .init(subscribe: { send, complete in
                send(DispatchedAction(action, dispatcher: source))
                complete()
                return .empty
            }, scheduling: scheduling)
        ])
    }

    /// Creates an effect that dispatches a sequence of actions in order, then signals completion.
    ///
    /// All actions are sent synchronously within the subscribe closure before `complete` is
    /// called. Each action carries the same call-site source location (the point where
    /// `Effect.sequence` is written, not the dispatch sites).
    ///
    /// ```swift
    /// // Dispatch multiple actions as a unit after a successful login
    /// return .produce { _ in
    ///     .sequence([.setUser(user), .loadDashboard, .trackLogin])
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - actions: The ordered list of raw actions to dispatch.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to ``EffectScheduling/immediately``.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    /// - Returns: A single-component ``Effect`` that sends each action in order then calls `complete`.
    public static func sequence(
        _ actions: [Action],
        scheduling: EffectScheduling = .immediately,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            .init(subscribe: { send, complete in
                for action in actions { send(DispatchedAction(action, dispatcher: source)) }
                complete()
                return .empty
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Forwarding factories (DispatchedAction — preserves existing source)

extension Effect {
    /// Creates an effect that dispatches a pre-sourced action, preserving its original dispatcher.
    ///
    /// Use this overload when re-dispatching an action that arrived from elsewhere (e.g., inside
    /// a middleware that forwards an action with its original call-site intact):
    ///
    /// ```swift
    /// // Forward the incoming action unchanged — same source, same action
    /// Middleware { action, _ in
    ///     Reader { _ in .just(action) }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - dispatched: The pre-sourced action to forward.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to ``EffectScheduling/immediately``.
    /// - Returns: A single-component ``Effect`` that sends `dispatched` then calls `complete`.
    public static func just(
        _ dispatched: DispatchedAction<Action>,
        scheduling: EffectScheduling = .immediately
    ) -> Self {
        Effect(components: [
            .init(subscribe: { send, complete in
                send(dispatched)
                complete()
                return .empty
            }, scheduling: scheduling)
        ])
    }

    /// Creates an effect that dispatches a sequence of pre-sourced actions in order,
    /// preserving their individual dispatchers.
    ///
    /// Each ``DispatchedAction`` carries its own ``ActionSource``, so different actions in
    /// the sequence can originate from different call sites.
    ///
    /// - Parameters:
    ///   - dispatched: The ordered list of pre-sourced actions to forward.
    ///   - scheduling: The ``EffectScheduling`` policy. Defaults to ``EffectScheduling/immediately``.
    /// - Returns: A single-component ``Effect`` that sends each action in order then calls `complete`.
    public static func sequence(
        _ dispatched: [DispatchedAction<Action>],
        scheduling: EffectScheduling = .immediately
    ) -> Self {
        Effect(components: [
            .init(subscribe: { send, complete in
                for d in dispatched { send(d) }
                complete()
                return .empty
            }, scheduling: scheduling)
        ])
    }
}

// MARK: - Cancellation sentinel

extension Effect {
    /// Creates a sentinel effect that cancels the running component registered under `id`
    /// without starting a new one.
    ///
    /// This is a pure cancellation operation — no `subscribe` closure is ever called. The
    /// Store interprets the embedded ``EffectScheduling/cancelInFlight(id:)`` scheduling by
    /// removing `id` from its registry and calling ``SubscriptionToken/cancel()`` on whatever
    /// was stored there.
    ///
    /// ```swift
    /// case .cancelDownload:
    ///     return .produce { _ in .cancelInFlight(id: "download") }
    ///
    /// case .startDownload(let url):
    ///     return .produce { env in
    ///         env.downloader.download(url).asEffect()
    ///             .scheduling(.replacing(id: "download"))
    ///     }
    /// ```
    ///
    /// - Parameter id: The key previously used when scheduling the component to cancel.
    ///   Must be `Hashable` and `Sendable`.
    /// - Returns: A sentinel ``Effect`` whose only purpose is to cancel the component with `id`.
    public static func cancelInFlight<H: Hashable & Sendable>(id: H) -> Self {
        Effect(components: [
            Component(
                subscribe: { _, complete in complete(); return .empty },
                scheduling: .cancelInFlight(id: AnyHashable(id))
            )
        ])
    }
}

// MARK: - Empty

extension Effect {
    /// An effect that does nothing — no actions produced, no work started.
    ///
    /// Equivalent to ``Monoid/identity`` and useful as a readable no-op return:
    ///
    /// ```swift
    /// case .noop:
    ///     return .produce { _ in .empty }
    /// ```
    ///
    /// - Note: This is exactly `Effect.identity` from the `Monoid` conformance. Both names
    ///   are available; prefer `.empty` in application code for clarity.
    public static var empty: Self { .identity }
}
