// MARK: - Convenience factories (raw Action — call site captured automatically)

extension Effect {
    /// Dispatches a single action immediately, then signals completion.
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

    /// Dispatches a sequence of actions in order, then signals completion.
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
    /// Dispatches a pre-sourced action, preserving its original dispatcher.
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

    /// Dispatches a sequence of pre-sourced actions in order, preserving their dispatchers.
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
    /// Cancels the running component with `id` without starting a new one.
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
    public static var empty: Self { .identity }
}
