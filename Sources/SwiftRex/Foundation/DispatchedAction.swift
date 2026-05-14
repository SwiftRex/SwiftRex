/// An action paired with the call-site that dispatched it.
///
/// Every action that enters the ``Store``'s dispatch pipeline is wrapped in a
/// `DispatchedAction`. The wrapper preserves the **provenance** of the action — the exact
/// file, function, and line where it originated — without requiring callers to pass that
/// information explicitly.
///
/// ## Where provenance comes from
///
/// - ``Store/dispatch(_:file:function:line:)`` captures `#file`, `#function`, and `#line`
///   at the call site automatically.
/// - ``Effect`` factories (``Effect/just(_:scheduling:file:function:line:)-5i6kl``,
///   ``Effect/sequence(_:scheduling:file:function:line:)``) do the same.
/// - The `here()` free function packages the source location into a reusable closure for
///   point-free pipelines.
///
/// ## Functor
///
/// `DispatchedAction` is a **Functor**: ``map(_:)`` transforms the wrapped action while
/// preserving the original dispatcher. ``compactMap(_:)`` does the same but returns `nil`
/// when the transform returns `nil` — used by lifting internals to filter actions:
///
/// ```swift
/// // Inside Middleware.liftAction(_:)
/// guard let local = incoming.compactMap(prism.preview) else { return Reader { _ in .empty } }
/// // local: DispatchedAction<LocalAction>, same dispatcher as incoming
/// ```
///
/// ## The `here()` function
///
/// `here()` captures the call site and returns a `(Action) -> DispatchedAction<Action>` function.
/// Because it is evaluated before `|>` applies its result, `#file`/`#function`/`#line` always
/// resolve at the source line, not inside a helper:
///
/// ```swift
/// AppAction.login(credentials) |> here()
/// ```
public struct DispatchedAction<Action: Sendable>: Sendable {
    /// The unwrapped action value.
    public let action: Action
    /// The call-site that dispatched this action.
    public let dispatcher: ActionSource

    /// Creates a `DispatchedAction` with an explicit dispatcher.
    ///
    /// Prefer the `#file`/`#function`/`#line` capturing overload for application code.
    /// Use this overload when forwarding an existing action whose provenance must be preserved
    /// unchanged.
    ///
    /// - Parameters:
    ///   - action: The action value.
    ///   - dispatcher: The ``ActionSource`` representing the call-site origin.
    public init(_ action: Action, dispatcher: ActionSource) {
        self.action = action
        self.dispatcher = dispatcher
    }

    /// Creates a `DispatchedAction` and automatically captures the call-site source location.
    ///
    /// Default `#file`, `#function`, and `#line` parameters resolve at the expression's source
    /// line, so the provenance is always accurate without any manual annotation:
    ///
    /// ```swift
    /// DispatchedAction(AppAction.login(credentials))
    /// // dispatcher.file == #file, dispatcher.line == this line
    /// ```
    ///
    /// - Parameters:
    ///   - action: The action value.
    ///   - file: Source file — captured automatically.
    ///   - function: Function name — captured automatically.
    ///   - line: Source line — captured automatically.
    public init(
        _ action: Action,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        self.init(action, dispatcher: ActionSource(file: file, function: function, line: line))
    }
}

/// Captures the call-site source location and returns a function that wraps any `Sendable`
/// action into a ``DispatchedAction``.
///
/// Designed for point-free pipelines with the `|>` forward-application operator:
///
/// ```swift
/// AppAction.login(credentials) |> here()
/// ```
///
/// Because `here()` is evaluated before `|>` applies its argument, `#file`, `#function`,
/// and `#line` resolve at the expression's source line — exactly where the dispatch originates,
/// not inside any helper function.
///
/// - Parameters:
///   - file: Source file — captured automatically.
///   - function: Function name — captured automatically.
///   - line: Source line — captured automatically.
/// - Returns: A function `(Action) -> DispatchedAction<Action>` that wraps an action with the
///   captured source location.
public func here<Action: Sendable>(
    file: String = #file,
    function: String = #function,
    line: UInt = #line
) -> (Action) -> DispatchedAction<Action> {
    let source = ActionSource(file: file, function: function, line: line)
    return { DispatchedAction($0, dispatcher: source) }
}

extension DispatchedAction {
    /// Transforms the wrapped action, preserving the original dispatcher.
    ///
    /// Used by ``Effect/map(_:)`` and by ``Middleware`` lift internals to change the action type
    /// while keeping full call-site provenance intact.
    ///
    /// ```swift
    /// let global: DispatchedAction<AppAction> = local.map { AppAction.auth($0) }
    /// ```
    ///
    /// - Parameter transform: A function from `Action` to `B`.
    /// - Returns: A `DispatchedAction<B>` with the same `dispatcher` and a transformed action.
    public func map<B: Sendable>(_ transform: @Sendable (Action) -> B) -> DispatchedAction<B> {
        DispatchedAction<B>(transform(action), dispatcher: dispatcher)
    }

    /// Optionally transforms the wrapped action, preserving the original dispatcher.
    ///
    /// Returns `nil` when `transform` returns `nil`, discarding the dispatched action
    /// entirely. Used in ``Middleware`` lift implementations to project a global action into
    /// an optional local action without losing the original dispatcher:
    ///
    /// ```swift
    /// // Inside Middleware.liftAction(_:)
    /// guard let local = incoming.compactMap(prism.preview) else {
    ///     return Reader { _ in .empty }
    /// }
    /// // local: DispatchedAction<AuthAction>, same dispatcher as incoming
    /// ```
    ///
    /// - Parameter transform: A partial function from `Action` to `B?`.
    /// - Returns: A `DispatchedAction<B>` with the same `dispatcher`, or `nil` if `transform`
    ///   returned `nil`.
    public func compactMap<B: Sendable>(
        _ transform: @Sendable (Action) -> B?
    ) -> DispatchedAction<B>? {
        transform(action).map { DispatchedAction<B>($0, dispatcher: dispatcher) }
    }
}
