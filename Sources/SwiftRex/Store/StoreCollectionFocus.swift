// SPDX-License-Identifier: Apache-2.0

import CoreFP

/// A store of **one element** of a collection — a pure stage between stores, like ``StoreProjection`` and
/// ``StoreBuffer``, specialised in collections. It follows its upstream and passes on the element with a given id
/// (or position, or dictionary key) — `nil` while it isn't there — and dispatches the element's actions through the
/// collection's element lane (`ElementAction(id, action)`).
///
/// ```swift
/// let row = store.projection(.action(\.row).state(\.rows), element: rowID)   // StoreCollectionFocus<RowAction, Row>
/// ```
///
/// **Finding the element.** The lane's `ix` (`element(id)`) is an affine traversal — correct, but a linear search
/// by id on every change. So each observer keeps an ``ElementHint`` — where it last found the element — and the
/// lane's locator searches outward from it: an element that didn't move costs one comparison, one that moved by
/// `k` (an insert or remove, or a block of `k`, before it) costs `k`. Every candidate is checked by id, so a stale
/// hint only costs steps. The hint lives in that observer's subscription, never in the upstream: nothing is cached
/// in a parent and nothing is asked of the state. By position and by key the lookup is O(1); a lane built from bare
/// optics (no locator) uses its `ix` as is.
///
/// Its state is optional because the element can go away. A view that shows it while it's there transposes it
/// (`viewStore.transpose(scope, element: id)` in SwiftUI) or wraps it in ``StoreOptionalFocus``.
@MainActor
public struct StoreCollectionFocus<Action: Sendable, Element: Sendable>: StoreType {
    /// The element over time, `nil` while it isn't in the collection.
    public let stateStream: StateStream<Element?>
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void

    /// Follows the element `id` of `store`'s collection, through the keyed `lane`; dispatches through `embed`.
    package init<S: StoreType, Lane: Relay.StateAxis.KeyedProtocol>(
        store: S,
        lane: Lane,
        id: Lane.ID,
        action embed: @escaping @Sendable (Action) -> S.Action
    ) where Lane.Global == S.State, Lane.Local == Element {
        stateStream = StateStream { onChange in
            let hint = ElementHint() // this observer's own: where it last found the element
            let (current, token) = store.stateStream.subscribe { onChange(lane.find(id, in: $0, hint: hint)) }
            return (lane.find(id, in: current, hint: hint), token)
        }
        _dispatch = { action, source in store.dispatch(embed(action), source: source) }
    }

    /// Forwards the element's action to the underlying store through the element lane.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }
}

// MARK: - Finding one element: the hint, the locator, the ix fallback

/// Where an observer last found its element — mutable, owned by that observer's subscription (or by the view store
/// that reads the element's presence). A custom ``Relay/StateAxis/ElementLocator`` receives one and passes it on.
///
/// `@unchecked Sendable`: created and used inside one subscription of a main-actor stream; never shared.
public final class ElementHint: @unchecked Sendable {
    var offset: Int?
    public init() {}
}

extension Relay.StateAxis {
    /// Finds one element of a keyed lane's container, using (and updating) an observer's hint.
    public typealias ElementLocator<Container, ID, Local> = @Sendable (Container, ID, ElementHint) -> Local?
}

extension Relay.StateAxis.KeyedProtocol {
    /// The element `id` in `global`: through the lane's locator, outward from `hint` (O(distance moved)) — or, for a
    /// lane without a locator, through its `ix` (`element(id)`, a linear search).
    package func find(_ id: ID, in global: Global, hint: ElementHint) -> Local? {
        let collection = container.get(global)
        return locate.map { $0(collection, id, hint) } ?? element(id).preview(collection)
    }
}

extension Collection {
    /// The element whose `identifier` is `id`, searched outward from the hint — O(distance moved); updates the hint.
    package func element<ID: Hashable>(id: ID, by identifier: KeyPath<Element, ID>, hint: ElementHint) -> Element? {
        let total = count
        guard total > 0 else { return nil }
        let start = Swift.min(Swift.max(hint.offset ?? 0, 0), total - 1)
        func element(at offset: Int) -> Element { self[index(startIndex, offsetBy: offset)] }
        for distance in 0..<total {
            let below = start - distance
            let above = start + distance
            if below < 0, above >= total { break }
            for offset in distance == 0 ? [start] : [below, above] where offset >= 0 && offset < total {
                let candidate = element(at: offset)
                if candidate[keyPath: identifier] == id {
                    hint.offset = offset
                    return candidate
                }
            }
        }
        return nil
    }

    /// The element at `position`, or `nil` out of bounds — O(1) (a bounds check, not `indices.contains`).
    package func element(at position: Index) -> Element? {
        position >= startIndex && position < endIndex ? self[position] : nil
    }
}
