import Foundation

/// A reference-type store wrapper that caches state and gates observer notifications
/// through a `hasChanged` predicate.
///
/// Unlike `StoreProjection` — which focuses on narrowing action and state types —
/// `StoreBuffer` is about **caching**: it owns a `state` snapshot and only fires
/// `willChange`/`didChange` when the predicate decides the new state is different.
///
/// Build in two explicit steps:
/// ```swift
/// // Step 1 — focus:  narrow the types via projection
/// let proj = appStore.projection(action: AppAction.counter, state: \.counterState)
///
/// // Step 2 — cache:  add deduplication
/// let buffered = proj.buffer()                         // CounterState: Equatable
/// let buffered = proj.buffer { $0.count != $1.count }  // custom predicate
/// ```
///
/// Timing: `willChange` fires **after** the underlying store mutation but **before**
/// `self.state` updates — correct for `ObservableObject` animation semantics.
@MainActor
public final class StoreBuffer<Action: Sendable, State: Sendable>
    : StoreType, @unchecked Sendable {
    public private(set) var state: State

    private let underlying: any StoreType<Action, State>
    private let hasChanged: @Sendable (State, State) -> Bool
    private var token: SubscriptionToken?
    private var observers: [UUID: (willChange: @MainActor @Sendable () -> Void,
                                   didChange: @MainActor @Sendable () -> Void)] = [:]

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

    public func dispatch(_ action: Action, source: ActionSource) {
        underlying.dispatch(action, source: source)
    }

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
    /// Uses `!=` as the predicate — the common case for `Equatable` states.
    public convenience init(_ store: some StoreType<Action, State>) {
        self.init(store, hasChanged: !=)
    }
}
