/// The call-site origin of a dispatched action, captured automatically at every public API boundary.
///
/// `ActionSource` records the `#file`, `#function`, and `#line` where an action was
/// dispatched or where an ``Effect`` factory was written. It is carried alongside every action
/// through the pipeline in a ``DispatchedAction``, making it available to logging, analytics,
/// and debugging ``Middleware`` values.
///
/// ## Automatic capture
///
/// You rarely need to create an `ActionSource` directly. Every public entry point captures it
/// via default parameter values:
///
/// - ``StoreType/dispatch(_:file:function:line:)`` — at the UI or coordinator call site.
/// - ``Effect/just(_:scheduling:file:function:line:)-5i6kl`` — at the effect factory call site.
/// - ``Effect/sequence(_:scheduling:file:function:line:)`` — same.
/// - ``DispatchedAction/init(_:file:function:line:)`` — when wrapping manually.
/// - The ``here()`` free function — for point-free pipelines.
///
/// ## Usage in middleware
///
/// ```swift
/// Middleware<AppAction, AppState, AppEnvironment> { action, _ in
///     Reader { env in
///         let source = action.dispatcher
///         env.logger.log("[\(source.file):\(source.line)] \(action.action)")
///         return .empty
///     }
/// }
/// ```
///
/// ## Hashable conformance
///
/// `ActionSource` conforms to `Hashable` so it can be used as a dictionary key — for
/// example, de-duplicating dispatch calls in tests or grouping analytics events by origin.
public struct ActionSource: Hashable, Sendable {
    /// The source file where the action was dispatched or the effect factory was written.
    ///
    /// Populated from `#file` — in Swift 5.3+ this is a module-relative path rather than
    /// the full filesystem path.
    public let file: String

    /// The function or closure name enclosing the dispatch call.
    ///
    /// Populated from `#function`.
    public let function: String

    /// The line number within `file` where the dispatch call appears.
    ///
    /// Populated from `#line`.
    public let line: UInt

    /// Creates an `ActionSource`, capturing the call site automatically via default parameters.
    ///
    /// In practice, this initialiser is called by effect factories and dispatch overloads —
    /// application code should not need to construct `ActionSource` directly.
    ///
    /// - Parameters:
    ///   - file: Source file — captured automatically via `#file`.
    ///   - function: Function name — captured automatically via `#function`.
    ///   - line: Source line — captured automatically via `#line`.
    public init(
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) {
        self.file = file
        self.function = function
        self.line = line
    }
}
