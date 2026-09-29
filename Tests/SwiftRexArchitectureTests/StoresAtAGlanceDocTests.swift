// SPDX-License-Identifier: Apache-2.0

// Checks the "who redraws?" table in `StoresAtAGlance.md`, row by row, under both signals.

#if canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import Combine
    import Foundation
    import Observation
    import SwiftRex
    @testable import SwiftRexSwiftUI
    import Testing

    private final class Hits: @unchecked Sendable {
        // Bumped from synchronous observation callbacks on the main actor only.
        private let lock = NSLock()
        private var _value = 0
        var value: Int { lock.withLock { _value } }
        func bump() { lock.withLock { _value += 1 } }
    }

    private struct Ble: Sendable, Equatable { var bli: Int; var blo: String }
    private struct Bla: Sendable, Equatable { var ble: Ble }
    private struct GlanceState: Sendable, Equatable { var bla = Bla(ble: Ble(bli: 1, blo: "x")); var other = 0 }

    private struct OpaqueBle: Sendable { var bli: Int }
    private struct OpaqueState: Sendable { var ble = OpaqueBle(bli: 1); var other = 0 }

    private enum Mutate<S: Sendable>: Sendable { case apply(@Sendable (inout S) -> Void) }

    @MainActor
    private func makeStore<S: Sendable>(_ initial: S) -> Store<Mutate<S>, S, Void> {
        Store(
            initial: initial,
            behavior: Reducer.reduce { (action: Mutate<S>, state: inout S) in
                switch action {
                case let .apply(f): f(&state)
                }
            }.asBehavior(),
            environment: ()
        )
    }

    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private func track(_ read: () -> Void) -> Hits {
        let hits = Hits()
        withObservationTracking(read) { hits.bump() }
        return hits
    }

    @Suite("Stores at a Glance — who redraws")
    @MainActor
    struct StoresAtAGlanceDocTests {
        // A: bla.ble.bli · B: bla.ble.value · C: node ble, reads blo · D: whole state
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        private func observers(_ store: ViewStore<Mutate<GlanceState>, GlanceState>) -> [Hits] {
            let ble = store.bla.ble
            return [
                track { _ = store.bla.ble.bli },
                track { _ = store.bla.ble.value },
                track { _ = ble.blo },
                track { _ = store.state }
            ]
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test(arguments: [
            ("bli 1→2", [1, 1, 0, 1]),
            ("blo x→y", [0, 1, 1, 1]),
            ("other 0→1", [0, 0, 0, 1]),
            ("bli 1→1", [0, 0, 0, 0])
        ])
        func observationRedrawsOnlyReadersOfChangedPaths(_ row: (String, [Int])) {
            let store = makeStore(GlanceState())
            let view = ViewStore(store.observable(.observation))   // the owner keeps it alive
            let hits = observers(view)
            store.dispatch(.apply(Self.change(row.0)))
            #expect(hits.map(\.value) == row.1, "\(row.0)")
            _ = view
        }

        @Test(arguments: [
            ("bli 1→2", true, 1),
            ("blo x→y", true, 1),
            ("other 0→1", true, 1),
            ("other 0→1", false, 0),
            ("bli 1→1", true, 0)
        ])
        func combineSendsOneSignalOnlyWhenAReadPathChanged(_ row: (String, Bool, Int)) {
            let store = makeStore(GlanceState())
            let observed = store.observable(.combine)
            let view = ViewStore(observed)
            _ = view.bla.ble.bli
            _ = view.bla.ble.value
            _ = view.bla.ble.blo
            if row.1 { _ = view.state }                          // with or without ViewD
            let sends = Hits()
            let cancellable = observed.objectWillChange.sink { sends.bump() }
            store.dispatch(.apply(Self.change(row.0)))
            #expect(sends.value == row.2, "\(row.0), ViewD: \(row.1)")
            cancellable.cancel()
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nonEquatableValueAlwaysCountsAsChanged() {
            let store = makeStore(OpaqueState())
            let view = ViewStore(store.observable(.observation))
            let whole = track { _ = view.ble.value }
            store.dispatch(.apply { $0.other += 1 })
            #expect(whole.value == 1)
        }

        private static func change(_ name: String) -> @Sendable (inout GlanceState) -> Void {
            switch name {
            case "bli 1→2": { $0.bla.ble.bli = 2 }
            case "blo x→y": { $0.bla.ble.blo = "y" }
            case "other 0→1": { $0.other = 1 }
            default: { $0.bla.ble.bli = 1 }
            }
        }
    }
#endif
