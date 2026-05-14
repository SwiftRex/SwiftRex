import Foundation

/// A reference-type store wrapper that caches state and gates observer notifications
/// through a `hasChanged` predicate.
///
/// While ``StoreProjection`` focuses on narrowing action and state types, `StoreBuffer`
/// focuses on **caching and deduplication**: it owns a `state` snapshot and only propagates
/// `willChange`/`didChange` to its own observers when `hasChanged(old, new)` returns `true`.
///
/// `StoreBuffer` is a **class** (reference type) because it must hold a previous-state
/// snapshot to diff against. A struct would lose the cached value on copy, making the
/// `hasChanged` comparison meaningless.
///
/// ## Building in two steps
///
/// The recommended pattern is to compose a ``StoreProjection`` (type narrowing) with a
/// `StoreBuffer` (notification gating):
///
/// ```swift
/// // Step 1 — narrow types via projection
/// let counterProj = appStore.projection(
///     action: { AppAction.counter($0) },
///     state:  { $0.counterState }
/// )
///
/// // Step 2 — add caching and deduplication (CounterState: Equatable)
/// let buffered = counterProj.buffer()
///
/// // Or with a custom predicate when Equatable is not available/desired
/// let buffered = counterProj.buffer { old, new in old.count != new.count }
/// ```
///
/// ## Notification timing
///
/// `StoreBuffer` subscribes to the underlying store's `didChange` notification. When `didChange`
/// fires, `StoreBuffer` reads the underlying store's new state and runs `hasChanged`. If the
/// predicate returns `true`:
///
/// 1. **`willChange` fires** (to its own observers) — before `self.state` is updated.
/// 2. **`self.state` is updated** to the new value.
/// 3. **`didChange` fires** (to its own observers) — after `self.state` is updated.
///
/// This ordering means `StoreBuffer`'s `willChange` fires *after* the underlying store's
/// mutation but *before* `self.state` updates — which is correct for `ObservableObject`
/// animation semantics.
///
/// ## Equatable shorthand
///
/// When `State: Equatable`, use the argument-free ``buffer()`` factory on ``StoreType``:
///
/// ```swift
/// let buffered = counterProj.buffer()  // uses !=
/// ```
///
/// - Note: `@unchecked Sendable` is used because the mutable stored properties (`state`,
///   `observers`, etc.) are only accessed on `@MainActor`, but Swift cannot statically prove
///   this for a `final class`.
@MainActor
public final class StoreBuffer<Action: Sendable, State: Sendable>
    : StoreType, @unchecked Sendable {
    /// The cached state snapshot.
    ///
    /// Updated only when `hasChanged(old, new)` returns `true`. Between updates, this value
    /// reflects the last state for which the predicate was satisfied.
    public private(set) var state: State

    private let underlying: any StoreType<Action, State>
    private let hasChanged: @Sendable (State, State) -> Bool
    private var token: SubscriptionToken?
    private var observers: [UUID: (willChange: @MainActor @Sendable () -> Void,
                                   didChange: @MainActor @Sendable () -> Void)] = [:]

    /// Creates a `StoreBuffer` wrapping `store` with a custom change predicate.
    ///
    /// The predicate receives the **old** cached state and the **new** underlying-store state.
    /// Returning `true` triggers a notification cycle; returning `false` suppresses it.
    ///
    /// ```swift
    /// // Only propagate when the visible item count changes
    /// let buffered = StoreBuffer(listStore) { old, new in old.items.count != new.items.count }
    /// ```
    ///
    /// - Parameters:
    ///   - store: The underlying ``StoreType`` to observe. The buffer holds a `weak` reference
    ///     to the underlying store's observer list via the returned ``SubscriptionToken``.
    ///   - hasChanged: A predicate called with `(oldState, newState)`. Return `true` to notify
    ///     the buffer's own observers and update the cached `state`.
    public init(
        _ store: some StoreType<Action, State>,
        hasChanged: @escaping @Sendable (State, State) -> Bool
    ) {
        self.underlying = store
        self.state = store.state
        self.hasChanged = hasChanged
        token = self.underlying.observe(
            willChange: {},
            didChange: { [weak self] in
                guard let self else { return }
                let new = self.underlying.state
                guard self.hasChanged(self.state, new) else { return }
                self.observers.values.forEach { $0.willChange() }
                self.state = new
                self.observers.values.forEach { $0.didChange() }
            }
        )
    }

    /// Forwards the dispatch call to the underlying store unchanged.
    ///
    /// - Parameters:
    ///   - action: The action to dispatch.
    ///   - source: The call-site provenance.
    public func dispatch(_ action: Action, source: ActionSource) {
        underlying.dispatch(action, source: source)
    }

    /// Registers callbacks that fire only when `hasChanged` returns `true`.
    ///
    /// Unlike registering directly on the underlying store (which fires on every mutation),
    /// callbacks registered on a `StoreBuffer` are gated by the predicate. This makes
    /// `StoreBuffer` useful for suppressing redundant UI updates in high-frequency dispatch
    /// scenarios.
    ///
    /// - Parameters:
    ///   - willChange: Called before `self.state` is updated (after the underlying mutation).
    ///   - didChange: Called after `self.state` is updated.
    /// - Returns: A ``SubscriptionToken`` that cancels both callbacks when cancelled.
    @discardableResult
    public func observe(
        willChange: @escaping @MainActor @Sendable () -> Void,
        didChange: @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken {
        let id = UUID()
        observers[id] = (willChange: willChange, didChange: didChange)
        return SubscriptionToken { [weak self] in
            Task { @MainActor [weak self] in self?.observers.removeValue(forKey: id) }
        }
    }
}

extension StoreBuffer where State: Equatable {
    /// Creates a `StoreBuffer` using `!=` as the change predicate.
    ///
    /// The most common case: notify observers only when the projected state actually differs
    /// from the cached value using `Equatable` equality.
    ///
    /// ```swift
    /// let buffered = counterProj.buffer()
    /// ```
    ///
    /// - Parameter store: The underlying ``StoreType`` to observe.
    public convenience init(_ store: some StoreType<Action, State>) {
        self.init(store, hasChanged: !=)
    }
}
