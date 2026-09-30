// SPDX-License-Identifier: Apache-2.0

/// A store of **one element** of a collection — a pure stage between stores, like ``StoreProjection`` and
/// ``StoreBuffer``, specialised in collections. It follows its upstream and passes on the element with a given id
/// (or position, or dictionary key) — `nil` while it isn't there — and dispatches the element's actions through the
/// collection's element lane (`ElementAction(id, action)`).
///
/// ```swift
/// let row = store.projection(.action(\.row).state(\.rows), element: rowID)   // StoreElement<RowAction, Row>
/// ```
///
/// **Finding the element stays cheap.** Each observer keeps a hint of where it last found the element and searches
/// outward from it: an element that didn't move costs one comparison, one that moved by `k` (an insert or remove —
/// or a block of `k` — before it) costs `k`. The hint lives in that observer's subscription, never in the upstream:
/// nothing is cached in a parent and nothing is asked of the state. By position and by key the lookup is O(1).
///
/// Its state is optional because the element can go away. A view that shows it while it's there transposes it
/// (`viewStore.transpose(scope, element: id)` in SwiftUI) or wraps it in ``StoreUnwrap``.
@MainActor
public struct StoreElement<Action: Sendable, Element: Sendable>: StoreType {
    /// The element over time, `nil` while it isn't in the collection.
    public let stateStream: StateStream<Element?>
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void

    /// A stage following `store` through `makeRead` — called once per subscription, so each observer gets its own
    /// lookup state.
    package init<S: StoreType>(
        store: S,
        action embed: @escaping @Sendable (Action) -> S.Action,
        read makeRead: @escaping @MainActor @Sendable () -> @MainActor (S.State) -> Element?
    ) {
        stateStream = StateStream { onChange in
            let read = makeRead()
            let (current, token) = store.stateStream.subscribe { onChange(read($0)) }
            return (read(current), token)
        }
        _dispatch = { action, source in store.dispatch(embed(action), source: source) }
    }

    /// Forwards the element's action to the underlying store through the element lane.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }
}
