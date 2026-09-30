// SPDX-License-Identifier: Apache-2.0

/// A store that skips repeated states: its ``stateStream`` passes a state on only when it differs from the
/// previous one — by `Equatable` (`!=`), or by a `hasChanged` predicate you supply. Dispatch goes straight
/// through to the underlying store.
///
/// Where it sits decides what it saves. **Before** a projection's map it deduplicates the map's *input*, so
/// the map doesn't run for changes elsewhere in the app — it stops redundant **recomputation**:
///
/// ```swift
/// let counter = appStore
///     .projection(action: { AppAction.counter($0) }, state: \.counter)   // the feature's slice
///     .buffer()                                                           // skip repeats of it (Counter.State: Equatable)
///     .projection(action: { $0 }, state: CounterView.ViewState.init)      // the view map runs only on real changes
/// ```
///
/// **After** a map it only drops identical results, so the map still runs on every upstream change. For
/// SwiftUI the `ViewStore` already signals only what each view read changed, so the buffer's job there is the
/// "before" one — `@Feature` builds exactly that chain when the feature's `State` is `Equatable`.
///
/// A `StoreBuffer` keeps no shared cache: each observer of its stream remembers its own previous value, so
/// creating one costs nothing until something observes it.
@MainActor
public struct StoreBuffer<Action: Sendable, State: Sendable>: StoreType {
    /// The underlying state over time, with repeats removed.
    public let stateStream: StateStream<State>
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void

    /// A buffer over `store` that passes a state on only when `hasChanged(previous, new)` is `true`.
    ///
    /// ```swift
    /// let buffered = StoreBuffer(listStore) { old, new in old.items.count != new.items.count }
    /// ```
    public init(
        _ store: some StoreType<Action, State>,
        hasChanged: @escaping @Sendable (State, State) -> Bool
    ) {
        stateStream = store.stateStream.removeDuplicates { !hasChanged($0, $1) }
        _dispatch = { action, source in store.dispatch(action, source: source) }
    }

    /// Forwards the action to the underlying store unchanged.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }
}

extension StoreBuffer where State: Equatable {
    /// A buffer over `store` that skips a state equal (`==`) to the previous one.
    ///
    /// ```swift
    /// let buffered = counterProj.buffer()
    /// ```
    public init(_ store: some StoreType<Action, State>) {
        self.init(store, hasChanged: !=)
    }
}
