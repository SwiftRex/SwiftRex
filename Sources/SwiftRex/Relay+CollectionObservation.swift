// SPDX-License-Identifier: Apache-2.0

import CoreFP

// MARK: - Reaching one element of a keyed lane by key path
//
// A view store records what a view reads **by key path**, so focusing one element of a collection needs a key path
// to that element — `\State.rows[element: id]` — not the `ix` closures a lift uses. A keyed lane built from a key
// path (`.state(\.rows)`, `.state(\.rows, id: \.slug)`, `.state(indexed: \.rows)`, `.state(dictionary: \.byID)`)
// carries a `KeyedObservation`: the collection's key path, and how to build the element's.
//
// Locating an element **by id** is a search; everything here exists to keep it O(1) without asking anything of the
// user's state (a plain array of `Identifiable` values is enough):
//
//   1. the element's key remembers where it was last found (a **hint**) and checks there first;
//   2. then the neighbours (`hint ± 1`) — one insert or remove shifts every later element by one;
//   3. then `hint + d`, with `d` the shift another element of the same collection just found (a block insert or
//      remove shifts everything after it by the same amount);
//   4. then an id → offset table built once per state change, only when a miss needs it — a shuffle or a sort;
//   5. and a plain search only when that table was built from a different state (a diff reading the old state).
//
// Every candidate is verified by id, so the hints only ever speed a lookup up; they can't make it wrong. By index and
// by dictionary key the lookup is already O(1) and needs none of this. Offsets go through the collection's own
// `index(_:offsetBy:)` — O(1) for arrays and every random-access collection. Observation plumbing: `package`.

extension Relay.StateAxis {
    /// How an observer reaches one element of a keyed lane by key path: the collection's key path from the lane's
    /// root, and the element's key path inside the collection. Present on lanes built from a key path; a lane built
    /// from a `Lens` has none, and a view store focusing it reads coarsely.
    public struct KeyedObservation<Global, Container, ID: Hashable & Sendable, Local>: Sendable {
        package let container: KeyPath<Global, Container> & Sendable
        package let element: @Sendable (ID, ElementLookup) -> KeyPath<Container, Local?>

        package init(
            container: KeyPath<Global, Container> & Sendable,
            element: @escaping @Sendable (ID, ElementLookup) -> KeyPath<Container, Local?>
        ) {
            self.container = container
            self.element = element
        }
    }
}

// MARK: - The per-collection lookup

/// Counts state changes, so an ``ElementLookup`` knows when its shift and its table belong to an older state.
/// One per view store engine, advanced on every new state.
///
/// `@unchecked Sendable`: key-path subscripts must be callable from any context, but this is only ever read and
/// advanced through a view store's reads, diffs and state changes, which all run on the main actor.
package final class ElementLookupClock: @unchecked Sendable {
    package var generation = 0
    package init() {}
}

/// The lookup accelerator for one collection in one view store: the shift learned during the current state change,
/// and the id → offset table built on the first miss that needs it. Both reset when the state changes.
///
/// `@unchecked Sendable`: only ever used through a view store's key-path reads on the main actor (see
/// ``ElementLookupClock``).
package final class ElementLookup: @unchecked Sendable {
    private let clock: ElementLookupClock
    private var generation = -1
    private var shift: Int?
    private var table: [AnyHashable: Int] = [:]
    private var hasTable = false

    package init(clock: ElementLookupClock) {
        self.clock = clock
    }

    /// The offset of the element with `id` in `collection`, or `nil` when it isn't there.
    func offset<C: Collection, ID: Hashable>(
        of id: ID,
        in collection: C,
        identifier: KeyPath<C.Element, ID>,
        hint: Int?
    ) -> Int? {
        if generation != clock.generation {
            generation = clock.generation
            shift = nil
            table = [:]
            hasTable = false
        }
        let count = collection.count
        func holds(_ offset: Int) -> Bool {
            offset >= 0 && offset < count
                && collection[collection.index(collection.startIndex, offsetBy: offset)][keyPath: identifier] == id
        }
        if let hint {
            if holds(hint) { return hint }
            let candidates = [hint - 1, hint + 1] + (shift.map { [hint + $0] } ?? [])
            if let found = candidates.first(where: holds) {
                shift = found - hint
                return found
            }
        }
        let fromTable = lookupTable(collection, identifier)[AnyHashable(id)].flatMap { holds($0) ? $0 : nil }
        let found = fromTable ?? rebuiltTable(collection, identifier)[AnyHashable(id)]
        if let found, let hint { shift = found - hint }
        return found
    }

    private func lookupTable<C: Collection, ID: Hashable>(_ collection: C, _ identifier: KeyPath<C.Element, ID>) -> [AnyHashable: Int] {
        hasTable ? table : rebuiltTable(collection, identifier)
    }

    private func rebuiltTable<C: Collection, ID: Hashable>(_ collection: C, _ identifier: KeyPath<C.Element, ID>) -> [AnyHashable: Int] {
        let built = Dictionary(
            collection.enumerated().map { (AnyHashable($0.element[keyPath: identifier]), $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        table = built
        hasTable = true
        return built
    }
}

// MARK: - Element keys (key-path components)

/// Where an element was last found — mutable, and excluded from its key's equality.
package final class ElementHint: @unchecked Sendable {
    // `@unchecked Sendable`: read and written only by a view store's key-path reads, on the main actor.
    var offset: Int?
    init() {}
}

/// The key-path component that reaches one element **by id** — equal for the same id, whatever the hint, so the
/// view store keeps one dependency per element however the collection moves.
package struct ObservedElementKey<Element, ID: Hashable & Sendable>: Hashable, @unchecked Sendable {
    // `@unchecked Sendable`: the identifier key path and the hint/lookup boxes are only used on the main actor.
    let id: ID
    let identifier: KeyPath<Element, ID>
    let hint: ElementHint
    let lookup: ElementLookup

    package init(id: ID, identifier: KeyPath<Element, ID>, lookup: ElementLookup) {
        self.id = id
        self.identifier = identifier
        self.lookup = lookup
        hint = ElementHint()
    }

    package static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.identifier == rhs.identifier }
    package func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Collection {
    /// The element with `key.id`, found through the key's hint and its collection's lookup; `nil` when absent.
    package subscript<ID>(observedElement key: ObservedElementKey<Element, ID>) -> Element? {
        guard let offset = key.lookup.offset(of: key.id, in: self, identifier: key.identifier, hint: key.hint.offset) else {
            return nil
        }
        key.hint.offset = offset
        return self[index(startIndex, offsetBy: offset)]
    }

    /// The element at `position`, or `nil` when it's out of bounds — by index, the user's choice and risk.
    package subscript(observedPosition position: Index) -> Element? where Index: Hashable {
        // A bounds check, not `indices.contains` — that is a linear search in a generic context.
        position >= startIndex && position < endIndex ? self[position] : nil
    }
}
