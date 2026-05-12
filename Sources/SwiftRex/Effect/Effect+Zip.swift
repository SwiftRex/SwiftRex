import Foundation

// MARK: - Applicative zip

extension Effect {
    /// Runs `self` and `other` concurrently; when both have emitted their **first** value,
    /// dispatches the pair. Additional emissions from either effect are ignored.
    ///
    /// **Scheduling is preserved.** Each component from `self` and `other` keeps its original
    /// `EffectScheduling` directive (debounce, throttle, cancellable id), so the Store schedules
    /// each independently. Cancelling a component by its id works exactly as if the zip did not
    /// exist.
    ///
    /// **Dispatcher.** The combined `DispatchedAction` carries the `zip` call site as its source,
    /// since zip is the conceptual dispatch point for the combined action.
    ///
    /// ```swift
    /// let pair: Effect<(UserProfile, Settings)> = fetchProfile.zip(fetchSettings)
    /// ```
    public func zip<B: Sendable>(
        _ other: Effect<B>,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<(Action, B)> {
        zipWith(other, { ($0, $1) }, file: file, function: function, line: line)
    }

    /// Runs `self` and `other` concurrently; when both have emitted their first value, applies
    /// `f` and dispatches the result. This is the applicative `liftA2` for `Effect`.
    ///
    /// Scheduling, cancellation, and dispatcher semantics are the same as `zip`.
    ///
    /// ```swift
    /// fetchProfile.zipWith(fetchSettings) { profile, settings in
    ///     AppState(profile: profile, settings: settings)
    /// }
    /// ```
    public func zipWith<B: Sendable, C: Sendable>(
        _ other: Effect<B>,
        _ f: @Sendable @escaping (Action, B) -> C,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<C> {
        let source = ActionSource(file: file, function: function, line: line)
        let state = ZipState<Action, B>()

        // Pass through each component with its original scheduling intact.
        // The Store schedules/cancels each component independently.
        let selfComponents = components.map { component in
            Effect<C>.Component(
                subscribe: { send in
                    component.subscribe { da in
                        state.setLeft(da.action) { a, b in
                            send(DispatchedAction(f(a, b), dispatcher: source))
                        }
                    }
                },
                scheduling: component.scheduling
            )
        }

        let otherComponents = other.components.map { component in
            Effect<C>.Component(
                subscribe: { send in
                    component.subscribe { db in
                        state.setRight(db.action) { a, b in
                            send(DispatchedAction(f(a, b), dispatcher: source))
                        }
                    }
                },
                scheduling: component.scheduling
            )
        }

        return Effect<C>(components: selfComponents + otherComponents)
    }
}

// MARK: - ZipState

/// Accumulates one value from each side; dispatches the combined result exactly once.
///
/// The `fired` flag prevents double-dispatch when concurrent emissions from multiple
/// components race — once both sides have contributed a value, all subsequent calls
/// are silently ignored.
private final class ZipState<A: Sendable, B: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var left: A?
    private var right: B?
    private var fired = false

    func setLeft(_ value: A, dispatch: (A, B) -> Void) {
        lock.withLock {
            guard !fired, left == nil else { return }
            left = value
            if let r = right { fired = true; dispatch(value, r) }
        }
    }

    func setRight(_ value: B, dispatch: (A, B) -> Void) {
        lock.withLock {
            guard !fired, right == nil else { return }
            right = value
            if let l = left { fired = true; dispatch(l, value) }
        }
    }
}
