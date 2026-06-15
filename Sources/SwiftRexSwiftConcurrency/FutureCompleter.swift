/// A single-use token passed to ``Effect/future(_:scheduling:file:function:line:)`` that
/// completes the future with exactly one action.
///
/// ## Compile-time safety
///
/// `FutureCompleter` is `~Copyable`: the Swift compiler prevents the value from being
/// duplicated. ``complete(_:)`` is a `consuming func`, which moves the completer out of
/// scope at the call site — attempting to call it a second time is a **compile-time error**.
///
/// ## Dropped completers
///
/// If you drop a `FutureCompleter` without calling ``complete(_:)`` (e.g., forgetting an
/// `else` branch), `deinit` fires automatically. It cancels the underlying
/// `CheckedContinuation`, preventing the internal `Task` from hanging. You will also see
/// a runtime warning similar to the one `CheckedContinuation` itself emits for the
/// "continuation resumed more than once" and "never resumed" cases.
///
/// ## Interaction model
///
/// You only ever see `FutureCompleter` as the parameter of the `work` closure in
/// ``Effect/future(_:scheduling:file:function:line:)``. Create no instances directly.
///
/// ```swift
/// Effect<AppAction>.future { completer in
///     URLSession.shared.dataTask(with: request) { data, _, error in
///         let action: AppAction = data
///             .flatMap { try? JSONDecoder().decode(MyModel.self, from: $0) }
///             .map { AppAction.didFetch(.success($0)) }
///             ?? AppAction.didFetch(.failure(error ?? URLError(.unknown)))
///         completer.complete(action)    // second call would not compile
///     }.resume()
/// }
/// ```
public struct FutureCompleter<Action: Sendable>: ~Copyable, @unchecked Sendable {
    private let box: FutureContinuationBox<Action>

    internal init(_ box: FutureContinuationBox<Action>) {
        self.box = box
    }

    /// Resolves the future with `action` and dispatches it to the store.
    ///
    /// This function **consumes** the `FutureCompleter`. After it returns, the completer no
    /// longer exists at the call site — calling it again is a compile-time error.
    ///
    /// - Parameter action: The action to dispatch. It is tagged with the ``ActionSource``
    ///   captured at the ``Effect/future(_:scheduling:file:function:line:)`` call site.
    public consuming func complete(_ action: Action) {
        box.complete(action)
    }

    deinit {
        // If the completer is dropped without calling complete (e.g. the user forgot an
        // else branch), resolve the continuation with nil so the Task doesn't hang forever.
        box.cancel()
    }
}
