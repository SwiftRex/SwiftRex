// SPDX-License-Identifier: Apache-2.0

import SwiftRex

// Key-path plumbing for granular observation. An observable store keys each dependency on a key path, and
// key-path literals are uniqued instances — so a read that reuses the same instance hits a pointer-keyed
// fast path instead of hashing the whole path. Everything here exists to keep composed paths (node hops,
// collection rows) on that fast path too: compositions are cached, rows are keyed by element id.

// MARK: - Public key-path components

/// The key-path component that addresses one element of an `Identifiable` collection **by id**, used by
/// ``GranularTracking/each(_:)`` rows. Two keys are equal when their ids are — the offset hint and the
/// fallback don't take part — so a row keeps the same dependency however the collection reorders.
///
/// Observation plumbing: you never build one by hand.
public struct ObservationElementKey<Element: Identifiable & Sendable>: Hashable, Sendable where Element.ID: Sendable {
    let id: Element.ID
    let offset: Int
    let fallback: Element

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension RandomAccessCollection where Element: Identifiable & Sendable, Element.ID: Sendable {
    /// The element with `key.id` — O(1) while it still sits at the offset it had when the row was built,
    /// a linear search after a reorder, and the last-known value once it's gone (a row can outlive its
    /// element for a frame while SwiftUI removes it). Observation plumbing behind ``GranularTracking`` rows.
    public subscript(observationElement key: ObservationElementKey<Element>) -> Element {
        let hinted = index(startIndex, offsetBy: key.offset, limitedBy: endIndex).flatMap { $0 == endIndex ? nil : $0 }
        return hinted.flatMap { self[$0].id == key.id ? self[$0] : nil }
            ?? first { $0.id == key.id }
            ?? key.fallback
    }

    /// The ids in order — what a list body depends on, so it redraws on insert / remove / reorder but not
    /// when a row's content changes. Observation plumbing behind ``GranularTracking/each(_:)``.
    public var observationIDs: [Element.ID] { map(\.id) }
}

extension Optional {
    /// `true` while `.some` — the presence edge a dismiss-only `Binding<Bool>` depends on, so a sheet redraws when it
    /// appears or disappears but not when the presented value changes. Observation plumbing.
    public var observationIsPresent: Bool { self != nil }
}

// MARK: - Path cache

/// What resolves a composed path's parent into the dependency guarding it — the observable store's registry.
@MainActor
protocol ObservationGuardResolver: AnyObject {
    func guardDependency<Root, Value>(_ path: KeyPath<Root, Value>) -> AnyObject?
}

/// Stable key-path instances for composed paths — the same instance for the same composition, so an
/// observable store's pointer-keyed registry keeps hitting its fast path.
@MainActor
final class ObservationPaths {
    private struct Pair: Hashable {
        let prefix: ObjectIdentifier
        let suffix: ObjectIdentifier
    }

    // Keys retain the key paths they were derived from, so an ObjectIdentifier can't be reused while cached.
    private var appended: [Pair: (prefix: AnyKeyPath, suffix: AnyKeyPath, result: AnyKeyPath)] = [:]
    private var rows: [ObjectIdentifier: (collection: AnyKeyPath, byID: [AnyHashable: (offset: Int, path: AnyKeyPath)])] = [:]
    // Every path this cache composed, pointing at the path it extends — so a dependency on `\.a.b.c` can be
    // skipped wholesale when `\.a.b` didn't change.
    private var parents: [ObjectIdentifier: (path: AnyKeyPath, resolve: (any ObservationGuardResolver) -> AnyObject?)] = [:]

    // Focused collection elements (`viewStore.focus(scope, element: id)`), created only when an element is focused:
    // the state-change counter their lookups share, one lookup per collection, and one path per element — the same
    // instance every render, so its position hint survives. See `Relay+CollectionObservation.swift` in SwiftRex.
    private var clock: ElementLookupClock?
    private var lookups: [ObjectIdentifier: (collection: AnyKeyPath, lookup: ElementLookup)] = [:]
    private var elements: [ElementPathKey: (collection: AnyKeyPath, path: AnyKeyPath)] = [:]

    private struct ElementPathKey: Hashable {
        let collection: ObjectIdentifier
        let id: AnyHashable
    }

    var count: Int { appended.count + rows.values.reduce(0) { $0 + $1.byID.count } + elements.count }

    /// A new state arrived: element lookups start over (their shift and table describe the previous state).
    func advanceGeneration() {
        clock?.generation &+= 1
    }

    /// The path to one element of the collection at `collection` — cached per (collection, id), linked to the
    /// collection so an unchanged collection skips it.
    func element<Root, Container, ID: Hashable & Sendable, Local>(
        _ collection: KeyPath<Root, Container>,
        id: ID,
        observation: Relay.StateAxis.KeyedObservation<some Any, Container, ID, Local>
    ) -> KeyPath<Root, Local?> {
        let key = ElementPathKey(collection: ObjectIdentifier(collection), id: AnyHashable(id))
        if let cached = elements[key]?.path as? KeyPath<Root, Local?> { return cached }
        let clock = self.clock ?? ElementLookupClock()
        self.clock = clock
        let lookup = lookups[ObjectIdentifier(collection)]?.lookup ?? ElementLookup(clock: clock)
        lookups[ObjectIdentifier(collection)] = (collection, lookup)
        let path = collection.appending(path: observation.element(id, lookup))
        elements[key] = (collection, path)
        link(path, to: collection)
        return path
    }

    /// The dependency guarding `path` — the one on the path it was composed from (`\.a.b` for `\.a.b.c`
    /// built by ``append(_:_:)``, the collection for a row built by ``rows(_:in:)``), resolved by the store;
    /// `nil` for a path this cache didn't compose.
    func parentGuard(of path: AnyKeyPath, in resolver: any ObservationGuardResolver) -> AnyObject? {
        parents[ObjectIdentifier(path)]?.resolve(resolver)
    }

    private func link<Root, Middle>(_ result: AnyKeyPath, to prefix: KeyPath<Root, Middle>) {
        parents[ObjectIdentifier(result)] = (prefix, { $0.guardDependency(prefix) })
    }

    func append<Root, Middle, Value>(_ prefix: KeyPath<Root, Middle>, _ suffix: KeyPath<Middle, Value>) -> KeyPath<Root, Value> {
        let key = Pair(prefix: ObjectIdentifier(prefix), suffix: ObjectIdentifier(suffix))
        return appended[key].flatMap { $0.result as? KeyPath<Root, Value> } ?? remember(key, prefix, suffix)
    }

    private func remember<Root, Middle, Value>(
        _ key: Pair,
        _ prefix: KeyPath<Root, Middle>,
        _ suffix: KeyPath<Middle, Value>
    ) -> KeyPath<Root, Value> {
        let result = prefix.appending(path: suffix)
        appended[key] = (prefix, suffix, result)
        link(result, to: prefix)
        return result
    }

    /// One stable path per element of `collection` (reached at `path`), keyed by id. Rows that left the
    /// collection are dropped; a row whose element moved gets a fresh path with an up-to-date offset hint
    /// (equal to the old one, so its registered dependency carries over).
    func rows<Root, C: RandomAccessCollection>(
        _ path: KeyPath<Root, C>,
        in collection: C
    ) -> [KeyPath<Root, C.Element>] where C.Element: Identifiable & Sendable, C.Element.ID: Sendable {
        let previous = rows[ObjectIdentifier(path)]?.byID ?? [:]
        var byID: [AnyHashable: (offset: Int, path: AnyKeyPath)] = [:]
        let paths = collection.enumerated().map { offset, element in
            let id = AnyHashable(element.id)
            let row = previous[id].flatMap { cached in
                cached.offset == offset ? cached.path as? KeyPath<Root, C.Element> : nil
            } ?? path.appending(path: \C[observationElement: ObservationElementKey(id: element.id, offset: offset, fallback: element)])
            byID[id] = (offset, row)
            link(row, to: path)
            return row
        }
        rows[ObjectIdentifier(path)] = (path, byID)
        return paths
    }

    func removeAll() {
        appended.removeAll(keepingCapacity: true)
        rows.removeAll(keepingCapacity: true)
        parents.removeAll(keepingCapacity: true)
        lookups.removeAll(keepingCapacity: true)
        elements.removeAll(keepingCapacity: true)
    }
}

// MARK: - Derived reads

/// The identity of a derived read — where it was made, the types it involves, and an optional caller id.
/// Two reads with the same identity are the same dependency, so a call site keeps one dependency however
/// often its body runs. Observation plumbing behind `ViewStore.read(derived:)`.
struct ObservationDerivedID: Hashable, Sendable {
    let site: String
    let types: [ObjectIdentifier]
    let id: AnyHashableSendable?
}

/// A key-path argument carrying a derivation — equal (and hashed) by its identity alone, since closures
/// can't be compared. Observation plumbing behind `ViewStore.read(derived:)`.
struct ObservationDerivedKey<Root, Value>: Hashable {
    let id: ObservationDerivedID
    let compute: (Root) -> Value

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
