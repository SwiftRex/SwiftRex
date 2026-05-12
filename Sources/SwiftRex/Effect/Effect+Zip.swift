import Foundation

// MARK: - Applicative zip

extension Effect {
    /// Runs `self` and `other` concurrently; when both have emitted their first value, dispatches
    /// the pair. Additional emissions from either effect are ignored after the pair is formed.
    /// Calls `complete` when both sides have completed.
    public func zip<B: Sendable>(
        _ other: Effect<B>,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<(Action, B)> {
        zipWith(other, { ($0, $1) }, file: file, function: function, line: line)
    }

    /// Runs `self` and `other` concurrently; when both have emitted their first value, applies `f`
    /// and dispatches the result. Calls `complete` when both sides have completed.
    public func zipWith<B: Sendable, C: Sendable>(
        _ other: Effect<B>,
        _ f: @Sendable @escaping (Action, B) -> C,
        file: String = #file,
        function: String = #function,
        line: UInt = #line
    ) -> Effect<C> {
        let source = ActionSource(file: file, function: function, line: line)
        let valueState = ZipValueState<Action, B>()
        let doneState = ZipDoneState()

        let selfComponents = components.map { component in
            Effect<C>.Component(
                subscribe: { send, complete in
                    component.subscribe(
                        { da in valueState.setLeft(da.action) { a, b in
                            send(DispatchedAction(f(a, b), dispatcher: source))
                        }},
                        { doneState.signalLeft { complete() } }
                    )
                },
                scheduling: component.scheduling
            )
        }

        let otherComponents = other.components.map { component in
            Effect<C>.Component(
                subscribe: { send, complete in
                    component.subscribe(
                        { db in valueState.setRight(db.action) { a, b in
                            send(DispatchedAction(f(a, b), dispatcher: source))
                        }},
                        { doneState.signalRight { complete() } }
                    )
                },
                scheduling: component.scheduling
            )
        }

        return Effect<C>(components: selfComponents + otherComponents)
    }
}

// MARK: - Shared state for zip

/// Accumulates one value from each side; dispatches combined result exactly once.
private final class ZipValueState<A: Sendable, B: Sendable>: @unchecked Sendable {
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

/// Tracks when both sides have completed; fires `onBothDone` exactly once.
private final class ZipDoneState: @unchecked Sendable {
    private let lock = NSLock()
    private var leftDone = false
    private var rightDone = false

    func signalLeft(onBothDone: () -> Void) {
        let both = lock.withLock { leftDone = true; return leftDone && rightDone }
        if both { onBothDone() }
    }

    func signalRight(onBothDone: () -> Void) {
        let both = lock.withLock { rightDone = true; return leftDone && rightDone }
        if both { onBothDone() }
    }
}
