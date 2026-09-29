// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI) && canImport(Combine)
    import Combine
    import Foundation
    import Observation
    import SwiftRex
    @testable import SwiftRexArchitecture
    @testable import SwiftRexSwiftUI
    import SwiftUI
    import Testing

    // MARK: - Fixtures

    private final class Counter: @unchecked Sendable {
        // Only mutated from observation callbacks, which fire synchronously on the main actor here.
        private let lock = NSLock()
        private var _value = 0
        var value: Int { lock.withLock { _value } }
        func bump() { lock.withLock { _value += 1 } }
    }

    private struct Transport: Sendable, Equatable {
        var position: Double = 0
        var isPlaying = false
    }

    private struct Mixer: Sendable, Equatable {
        var volume: Double = 1
        var muted = false
    }

    private struct Song: Sendable, Equatable, Identifiable {
        var id: Int
        var title: String
    }

    // Not Equatable: `.value` reads of it must always count as changed.
    private struct Opaque: Sendable {
        var n = 0
    }

    private struct Screen: Sendable, Equatable {
        var title = "a"
        var count = 0
        var transport = Transport()
        var mixer = Mixer()
        var songs: [Song] = [Song(id: 1, title: "one"), Song(id: 2, title: "two")]
        var detail: Transport?
        var opaque = Opaque()

        static func == (lhs: Screen, rhs: Screen) -> Bool {
            lhs.title == rhs.title && lhs.count == rhs.count && lhs.transport == rhs.transport
                && lhs.mixer == rhs.mixer && lhs.songs == rhs.songs && lhs.detail == rhs.detail
                && lhs.opaque.n == rhs.opaque.n
        }
    }

    private enum ScreenAction: Sendable {
        case mutate(@Sendable (inout Screen) -> Void)
        case transport(TransportAction)
    }

    private enum TransportAction: Sendable {
        case play
    }

    @MainActor
    private func makeStore(_ initial: Screen = Screen()) -> Store<ScreenAction, Screen, Void> {
        Store(
            initial: initial,
            behavior: Reducer.reduce { (action: ScreenAction, state: inout Screen) in
                switch action {
                case let .mutate(f): f(&state)
                case .transport(.play): state.transport.isPlaying = true
                }
            }.asBehavior(),
            environment: ()
        )
    }

    /// Arms one Observation tracking of `read`; the counter goes up when something `read` touched changes.
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    private func track(_ read: () -> Void) -> Counter {
        let counter = Counter()
        withObservationTracking(read) { counter.bump() }
        return counter
    }

    // MARK: - Granularity

    @Suite("ObservableStore — granular reads")
    @MainActor
    struct ObservableStoreGranularityTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func seedsAndForwardsDispatch() {
            let store = makeStore()
            let observed = store.observable()
            #expect(observed.title == "a")
            observed.dispatch(.mutate { $0.title = "b" })
            #expect(store.state.title == "b")
            #expect(observed.title == "b")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func leafReadDependsOnItsPathOnly() {
            let store = makeStore()
            let observed = store.observable()
            let title = track { _ = observed.title }
            let count = track { _ = observed.count }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(title.value == 0)
            #expect(count.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nestedReadsAreGranular() {
            let store = makeStore()
            let observed = store.observable()
            let position = track { _ = observed.transport.position }
            let playing = track { _ = observed.transport.isPlaying }
            store.dispatch(.mutate { $0.transport.position = 3 })
            #expect(position.value == 1)
            #expect(playing.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nodeHopsAndDirectPathsAreTheSameDependency() {
            let store = makeStore()
            let observed = store.observable()
            let viaNode = track { _ = observed.transport.position }
            let direct = track { _ = observed.read(\.transport.position) }
            store.dispatch(.mutate { $0.transport.position = 1 })
            #expect(viaNode.value == 1)
            #expect(direct.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func sameValueWriteDoesNotInvalidate() {
            let store = makeStore()
            let observed = store.observable()
            let title = track { _ = observed.title }
            store.dispatch(.mutate { $0.title = "a" })
            #expect(title.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func equatableNodeValueComparesWhole() {
            let store = makeStore()
            let observed = store.observable()
            let mixer = track { _ = observed.mixer.value }
            store.dispatch(.mutate { $0.mixer = Mixer() })
            #expect(mixer.value == 0)
            store.dispatch(.mutate { $0.mixer.muted = true })
            #expect(mixer.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nonEquatableValueAlwaysCountsAsChanged() {
            let store = makeStore()
            let observed = store.observable()
            let opaque = track { _ = observed.opaque.value }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(opaque.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func wholeStateReadIsCoarse() {
            let store = makeStore()
            let observed = store.observable()
            let whole = track { _ = observed.state }
            store.dispatch(.mutate { $0.mixer.volume = 0.5 })
            #expect(whole.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func optionalPresenceDependsOnTheEdgeOnly() {
            let store = makeStore(Screen(detail: Transport()))
            let observed = store.observable()
            let present = track { _ = observed.detail.isPresent() }
            store.dispatch(.mutate { $0.detail?.position = 9 })
            #expect(present.value == 0)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(present.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func unwrappedNodeReadsThroughAndSurvivesNil() {
            let store = makeStore(Screen(detail: Transport(position: 2)))
            let observed = store.observable()
            let detail = observed.detail.unwrapped()
            #expect(detail?.position == 2)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(observed.detail.unwrapped() == nil)
            #expect(detail?.position == 2) // a lingering node reads its last-known value
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func hotAndColdRegionsAreIndependent() {
            let store = makeStore()
            let observed = store.observable()
            let ticks = 50
            var hot = 0
            var cold = 0
            for tick in 0..<ticks {
                let playhead = track { _ = observed.transport.position }
                let console = track {
                    _ = observed.mixer.volume
                    _ = observed.mixer.muted
                    _ = observed.title
                }
                store.dispatch(.mutate { $0.transport.position = Double(tick + 1) })
                hot += playhead.value
                cold += console.value
            }
            #expect(hot == ticks)
            #expect(cold == 0)
        }
    }

    // MARK: - Collections

    @Suite("ObservableStore — each")
    @MainActor
    struct ObservableStoreEachTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowsDependOnTheirOwnElement() {
            let store = makeStore()
            let observed = store.observable()
            let rows = observed.each(\.songs)
            #expect(rows.map(\.id) == [1, 2])
            let first = track { _ = rows[0].title }
            let second = track { _ = rows[1].title }
            store.dispatch(.mutate { $0.songs[1].title = "TWO" })
            #expect(first.value == 0)
            #expect(second.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func listDependsOnIdsOnly() {
            let store = makeStore()
            let observed = store.observable()
            let content = track { _ = observed.each(\.songs) }
            store.dispatch(.mutate { $0.songs[0].title = "ONE" })
            #expect(content.value == 0)
            let membership = track { _ = observed.each(\.songs) }
            store.dispatch(.mutate { $0.songs.append(Song(id: 3, title: "three")) })
            #expect(membership.value == 1)
            let order = track { _ = observed.each(\.songs) }
            store.dispatch(.mutate { $0.songs.reverse() })
            #expect(order.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowsFollowTheirElementAcrossReordersAndOutliveRemoval() {
            let store = makeStore()
            let observed = store.observable()
            let second = observed.each(\.songs)[1]
            store.dispatch(.mutate { $0.songs.reverse() })
            #expect(second.title == "two")
            store.dispatch(.mutate { $0.songs.removeAll { $0.id == 2 } })
            #expect(second.title == "two") // last-known value, no crash
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowPathsAreStableInstances() {
            let observed = makeStore().observable()
            let first = observed.each(\.songs).map { ObjectIdentifier($0.path) }
            let second = observed.each(\.songs).map { ObjectIdentifier($0.path) }
            #expect(first == second)
        }
    }

    // MARK: - Registry and notification gating

    @Suite("ObservableStore — registry and gating")
    @MainActor
    struct ObservableStoreRegistryTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func firedDependenciesDisarmUntilReadAgain() {
            let store = makeStore()
            let observed = store.observable()
            _ = track { _ = observed.title }
            _ = track { _ = observed.count }
            #expect(observed.armedCount == 2)
            store.dispatch(.mutate { $0.title = "b" })
            #expect(observed.armedCount == 1)
            _ = observed.title
            #expect(observed.armedCount == 2)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func ownObserversFireOnlyWhenTheSnapshotChanged() {
            let store = makeStore()
            let observed = store.observable()
            let counter = Counter()
            let token = observed.observe(didChange: { counter.bump() })
            store.dispatch(.mutate { $0.title = "a" }) // no-op write
            #expect(counter.value == 0)
            store.dispatch(.mutate { $0.title = "b" })
            #expect(counter.value == 1)
            token.cancel()
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func mapRunsOncePerChangeHoweverManyReads() {
            let store = makeStore()
            let maps = Counter()
            let observed = store
                .projection(action: { $0 }, state: { (s: Screen) -> Transport in maps.bump(); return s.transport })
                .observable()
            let baseline = maps.value
            store.dispatch(.mutate { $0.transport.position = 1 })
            for _ in 0..<10 { _ = observed.position }
            #expect(maps.value == baseline + 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func bufferBeforeTheMapSkipsItForUnrelatedChanges() {
            let store = makeStore()
            let maps = Counter()
            let observed = store
                .projection(action: { $0 }, state: \.transport)
                .buffer()
                .projection(action: { $0 }, state: { (t: Transport) -> Double in maps.bump(); return t.position })
                .observable()
            let baseline = maps.value
            store.dispatch(.mutate { $0.mixer.volume = 0 })
            store.dispatch(.mutate { $0.title = "z" })
            #expect(maps.value == baseline)
            store.dispatch(.mutate { $0.transport.position = 4 })
            #expect(maps.value == baseline + 1)
            #expect(observed.state == 4)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func featureFactoryBuffersEquatableState() {
            let store = makeStore()
            let maps = Counter()
            let feature = store.projection(action: { $0 }, state: \.transport)
            let observed = ObservableStore<ScreenAction, Double>.feature(
                feature,
                environment: (),
                action: Reader { _ in { @Sendable action in action } },
                state: Reader { _ in { (t: Transport) -> Double in maps.bump(); return t.position } },
                strategy: .observation
            )
            let baseline = maps.value
            store.dispatch(.mutate { $0.count += 1 })
            #expect(maps.value == baseline)
            store.dispatch(.mutate { $0.transport.position = 2 })
            #expect(observed.state == 2)
        }
    }

    // MARK: - Scoped stores

    @Suite("ObservableStore — scoped")
    @MainActor
    struct ScopedStoreTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func scopedStoreReadsGranularlyAndDispatchesThroughItsLane() {
            let store = makeStore()
            let observed = store.observable()
            let transport = observed.transport.scoped(action: .action(review: ScreenAction.transport))
            let playing = track { _ = transport.isPlaying }
            let position = track { _ = transport.position }
            transport.dispatch(.play)
            #expect(store.state.transport.isPlaying)
            #expect(playing.value == 1)
            #expect(position.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func scopedStoreSupportsBindings() {
            let store = makeStore()
            let transport = store.observable().transport.scoped(action: .action(review: ScreenAction.transport))
            let playing = transport.binding(.state(\.isPlaying), dispatch: .action(review: { (_: Bool) in TransportAction.play }))
            #expect(playing.wrappedValue == false)
            playing.wrappedValue = true
            #expect(store.state.transport.isPlaying)
        }
    }

    // MARK: - Bindings

    @Suite("ObservableStore — binding registration")
    @MainActor
    struct ObservableStoreBindingTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func presenceDependsOnThePresenceEdge() {
            let store = makeStore(Screen(detail: Transport()))
            let observed = store.observable()
            let presence = observed.presence(.state(\.detail), dismiss: .mutate { $0.detail = nil })
            let edge = track { _ = presence.wrappedValue }
            store.dispatch(.mutate { $0.detail?.position = 3 })
            #expect(edge.value == 0)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(edge.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func closureLaneFallsBackToWholeState() {
            let store = makeStore()
            let observed = store.observable()
            let presence = observed.presence(.state { $0.detail }, dismiss: .mutate { $0.detail = nil })
            let whole = track { _ = presence.wrappedValue }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(whole.value == 1)
        }
    }

    // MARK: - Combine strategy

    @Suite("ObservableStore — combine")
    @MainActor
    struct ObservableStoreCombineTests {
        @Test func objectWillChangeOnlyWhenAReadPathChanged() {
            let store = makeStore()
            let observed = store.observable(.combine)
            let sends = Counter()
            let cancellable = observed.objectWillChange.sink { sends.bump() }
            store.dispatch(.mutate { $0.count += 1 }) // nothing read yet
            #expect(sends.value == 0)
            _ = observed.title
            store.dispatch(.mutate { $0.count += 1 }) // unread path
            #expect(sends.value == 0)
            store.dispatch(.mutate { $0.title = "b" }) // read path
            #expect(sends.value == 1)
            store.dispatch(.mutate { $0.title = "c" }) // cleared until re-read by a render
            #expect(sends.value == 1)
            _ = observed.title
            store.dispatch(.mutate { $0.title = "d" })
            #expect(sends.value == 2)
            cancellable.cancel()
        }

        @Test func observationStrategyNeverSendsObjectWillChange() {
            guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else { return }
            let store = makeStore()
            let observed = store.observable()
            let sends = Counter()
            let cancellable = observed.objectWillChange.sink { sends.bump() }
            _ = observed.title
            store.dispatch(.mutate { $0.title = "b" })
            #expect(sends.value == 0)
            cancellable.cancel()
        }
    }

    // MARK: - Host

    @Suite("ObservableStoreHost")
    @MainActor
    struct ObservableStoreHostTests {
        @Test func boxBuildsOncePerId() {
            let store = makeStore()
            let makes = Counter()
            let box = ObservableStoreHost<ScreenAction, Screen, EmptyView>.Box()
            let make = { () -> ObservableStore<ScreenAction, Screen> in
                makes.bump()
                return store.observable(.combine)
            }
            let first = box.store(id: nil, make: make)
            let again = box.store(id: nil, make: make)
            #expect(first === again)
            #expect(makes.value == 1)
            let other = box.store(id: 1, make: make)
            #expect(other !== first)
            #expect(makes.value == 2)
        }
    }
#endif
