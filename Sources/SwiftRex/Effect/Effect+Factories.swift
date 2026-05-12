// MARK: - Convenience factories (raw Action — call site captured automatically)

extension Effect {
    /// Dispatches a single action immediately. The call site is captured as the dispatcher source.
    public static func just(
        _ action: Action,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            .init(subscribe: { send in
                send(DispatchedAction(action, dispatcher: source))
                return .empty
            }, scheduling: .immediately)
        ])
    }

    /// Dispatches a sequence of actions in order. The call site is captured as the dispatcher source.
    public static func sequence(
        _ actions: [Action],
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Self {
        let source = ActionSource(file: file, function: function, line: line)
        return Effect(components: [
            .init(subscribe: { send in
                for action in actions { send(DispatchedAction(action, dispatcher: source)) }
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
            .init(subscribe: { send in send(dispatched); return .empty }, scheduling: .immediately)
        ])
    }

    /// Dispatches a sequence of pre-sourced actions in order, preserving their dispatchers.
    public static func sequence(_ dispatched: [DispatchedAction<Action>]) -> Self {
        Effect(components: [
            .init(subscribe: { send in
                for d in dispatched { send(d) }
                return .empty
            }, scheduling: .immediately)
        ])
    }
}

// MARK: - Cancellation sentinel

extension Effect {
    /// Cancels the running component with `id` without starting a new one.
    public static func cancelInFlight<H: Hashable & Sendable>(id: H) -> Self {
        Effect(components: [
            Component(subscribe: { _ in .empty }, scheduling: .cancelInFlight(id: AnyHashable(id)))
        ])
    }
}

// MARK: - Empty

extension Effect {
    /// An effect that does nothing. Equivalent to `Monoid.identity`.
    public static var empty: Self { .identity }
}
