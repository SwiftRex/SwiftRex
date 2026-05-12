/// A single-use token passed to `Effect.future` that lets the caller complete the future
/// with exactly one action.
///
/// `FutureCompleter` is `~Copyable`: the compiler prevents it from ever being duplicated.
/// `complete` is a `consuming func`: calling it moves the completer out of scope, making
/// a second call a **compile-time error**. Dropping a `FutureCompleter` without calling
/// `complete` fires `deinit`, which cancels the underlying continuation and emits a runtime
/// warning — the same safety net `CheckedContinuation` provides for the never-called case.
///
/// This type is an implementation detail of `Effect.future`. Users interact with it only
/// as the parameter of the work closure:
/// ```swift
/// Effect.future { completer in
///     URLSession.shared.dataTask(with: url) { data, _, _ in
///         completer.complete(parseAction(data))   // compile error if called twice
///     }.resume()
/// }
/// ```
public struct FutureCompleter<Action: Sendable>: ~Copyable, @unchecked Sendable {
    private let box: FutureContinuationBox<Action>

    internal init(_ box: FutureContinuationBox<Action>) {
        self.box = box
    }

    /// Complete the future with `action`. This **consumes** the completer — a second call
    /// is a compile-time error.
    public consuming func complete(_ action: Action) {
        box.complete(action)
    }

    deinit {
        // If the completer is dropped without calling complete (e.g. the user forgot an
        // else branch), resolve the continuation with nil so the Task doesn't hang forever.
        box.cancel()
    }
}
