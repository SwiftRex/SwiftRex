import Foundation

// MARK: - Applicative zip

extension Effect {
    /// Runs `self` and `other` concurrently; when both have emitted their first value, dispatches
    /// the pair. Additional emissions from either effect are ignored after the pair is formed.
    ///
    /// The combined action carries the dispatcher of whichever emission completed the pair.
    ///
    /// ```swift
    /// let pair: Effect<(UserProfile, Settings)> =
    ///     fetchProfile.zip(fetchSettings)
    /// ```
    public func zip<B: Sendable>(_ other: Effect<B>) -> Effect<(Action, B)> {
        zipWith(other) { ($0, $1) }
    }

    /// Runs `self` and `other` concurrently; when both have emitted their first value, combines
    /// them with `f` and dispatches the result. Additional emissions are ignored after the pair
    /// is formed.
    ///
    /// This is the applicative `liftA2` for `Effect`:
    /// ```swift
    /// fetchProfile.zipWith(fetchSettings) { profile, settings in
    ///     AppState(profile: profile, settings: settings)
    /// }
    /// ```
    public func zipWith<B: Sendable, C: Sendable>(
        _ other: Effect<B>,
        _ f: @Sendable @escaping (Action, B) -> C
    ) -> Effect<C> {
        Effect<C>(components: [
            Effect<C>.Component(
                subscribe: { send in
                    let state = ZipState<Action, B>()
                    let tokenA = self.subscribeFirst { da in
                        state.setLeft(da, combine: f, send: send)
                    }
                    let tokenB = other.subscribeFirst { db in
                        state.setRight(db, combine: f, send: send)
                    }
                    return SubscriptionToken { tokenA.cancel(); tokenB.cancel() }
                },
                scheduling: .immediately
            )
        ])
    }
}

// Subscribes all components of an effect, forwarding only the first emission.
private extension Effect {
    func subscribeFirst(
        _ handler: @escaping @Sendable (DispatchedAction<Action>) -> Void
    ) -> SubscriptionToken {
        let fired = ZipFireOnce()
        let tokens = components.map { component in
            component.subscribe { da in
                guard fired.tryFire() else { return }
                handler(da)
            }
        }
        return SubscriptionToken { for t in tokens { t.cancel() } }
    }
}

// MARK: - Helpers

/// Thread-safe flag: allows exactly one `tryFire()` to return `true`.
private final class ZipFireOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    func tryFire() -> Bool {
        lock.withLock {
            guard !fired else { return false }
            fired = true
            return true
        }
    }
}

/// Accumulates one value from each side; dispatches the combined result on the second arrival.
private final class ZipState<A: Sendable, B: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var left: DispatchedAction<A>?
    private var right: DispatchedAction<B>?

    func setLeft<C: Sendable>(
        _ da: DispatchedAction<A>,
        combine f: @Sendable @escaping (A, B) -> C,
        send: @Sendable @escaping (DispatchedAction<C>) -> Void
    ) {
        lock.withLock {
            left = da
            if let r = right {
                send(DispatchedAction(f(da.action, r.action), dispatcher: da.dispatcher))
            }
        }
    }

    func setRight<C: Sendable>(
        _ db: DispatchedAction<B>,
        combine f: @Sendable @escaping (A, B) -> C,
        send: @Sendable @escaping (DispatchedAction<C>) -> Void
    ) {
        lock.withLock {
            right = db
            if let l = left {
                send(DispatchedAction(f(l.action, db.action), dispatcher: db.dispatcher))
            }
        }
    }
}
