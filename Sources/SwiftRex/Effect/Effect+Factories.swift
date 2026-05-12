// MARK: - Convenience factories (raw Action — call site captured automatically)

extension Effect {
    /// Dispatches a single action immediately, then signals completion.
    public static func just(
        _ action: Action,
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
            }, scheduling: .immediately)
        ])
    }

    /// Dispatches a sequence of actions in order, then signals completion.
    public static func sequence(
        _ actions: [Action],
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
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Forwarding factories (DispatchedAction — preserves existing source)

extension Effect {
    /// Dispatches a pre-sourced action, preserving its original dispatcher.
    public static func just(_ dispatched: DispatchedAction<Action>) -> Self {
        Effect(components: [
            .init(subscribe: { send, complete in
                send(dispatched)
                complete()
                return .empty
            }, scheduling: .immediately)
        ])
    }

    /// Dispatches a sequence of pre-sourced actions in order, preserving their dispatchers.
    public static func sequence(_ dispatched: [DispatchedAction<Action>]) -> Self {
        Effect(components: [
            .init(subscribe: { send, complete in
                for d in dispatched { send(d) }
                complete()
                return .empty
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Cancellation sentinel

extension Effect {
    /// Cancels the running component with `id` without starting a new one.
    ///
    /// The subscribe closure for `.cancelInFlight` is never called by the Store — it is a
    /// pure scheduling sentinel. `complete()` would be a no-op here, but is included for
    /// signature compliance.
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
    /// An effect that does nothing. Equivalent to `Monoid.identity`.
    ///
    /// `empty.then(next)` reduces to `next` because `empty` has no components and
    /// `then` short-circuits to `next` when `self.components.isEmpty`.
    public static var empty: Self { .identity }
}
