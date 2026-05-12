/// An action paired with the call-site that dispatched it.
///
/// Middleware receives `DispatchedAction<InputAction>` on the incoming side, giving access to
/// both the action and its origin for logging, tracing, and analytics. On the outgoing side
/// middlewares return raw `Action` values; the framework wraps them using the source captured
/// at the `Effect` factory call site.
public struct DispatchedAction<Action: Sendable>: Sendable {
    public let action: Action
    public let dispatcher: ActionSource

    public init(_ action: Action, dispatcher: ActionSource) {
        self.action = action
        self.dispatcher = dispatcher
    }
}

extension DispatchedAction {
    /// Transforms the action, preserving the original dispatcher.
    ///
    /// Used by `Effect.map` and by Middleware lift internals to change the action type
    /// while keeping full call-site provenance intact.
    public func map<B: Sendable>(_ transform: @Sendable (Action) -> B) -> DispatchedAction<B> {
        DispatchedAction<B>(transform(action), dispatcher: dispatcher)
    }

    /// Optionally transforms the action, preserving the original dispatcher.
    ///
    /// Returns `nil` when `transform` returns `nil`, discarding the dispatched action entirely.
    /// Used in Middleware lift implementations to project `DispatchedAction<GlobalAction>` into
    /// `DispatchedAction<LocalAction>?` without losing the original dispatcher:
    ///
    /// ```swift
    /// guard let local = incoming.compactMap(\.asAuthAction) else { return .pure(.empty) }
    /// // local: DispatchedAction<AuthAction>, same dispatcher as incoming
    /// ```
    public func compactMap<B: Sendable>(
        _ transform: @Sendable (Action) -> B?
    ) -> DispatchedAction<B>? {
        transform(action).map { DispatchedAction<B>($0, dispatcher: dispatcher) }
    }
}
