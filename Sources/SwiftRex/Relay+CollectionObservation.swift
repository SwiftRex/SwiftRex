// SPDX-License-Identifier: Apache-2.0

import CoreFP

// MARK: - Finding one element of a keyed lane, fast, per observer
//
// A keyed lane's `element(id)` is an `ix` affine traversal — correct, but a linear search by id. A stage that follows
// one element over time (``StoreElement``) keeps a **hint** — where it last found its element — and searches outward
// from it: an element that didn't move is found at once; one that moved by `k` (an insert or remove, or a block of
// `k` before it) is found after `k` steps. The hint belongs to the observer (created when it subscribes), never to a
// parent or a shared cache, and every candidate is checked by id, so a stale hint only costs steps.
//
// By position and by dictionary key the lookup is already O(1). Nothing is asked of the state: a plain array of
// `Identifiable` values (or a custom id key path) is enough.

/// Where an observer last found its element — mutable, owned by that observer's subscription. Opaque plumbing
/// behind ``Relay/StateAxis/ElementLocator``: a custom locator receives one and passes it on to the lookups below.
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
