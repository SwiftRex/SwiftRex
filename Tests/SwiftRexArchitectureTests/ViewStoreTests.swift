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

    /// The key path a row position reads through (row paths are cached, so the same element gets the same instance).
    @MainActor
    private func rowPath(_ row: GranularTracking<Song>) -> ObjectIdentifier? {
        (row.reader as? SliceReader<ScreenAction, Screen, Song>).map { ObjectIdentifier($0.prefix) }
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

    @Suite("ViewStore — granular reads")
    @MainActor
    struct ViewStoreGranularityTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func seedsAndForwardsDispatch() {
            let store = makeStore()
            let observed = store.viewStore()
            #expect(observed.state.title == "a")
            observed.dispatch(.mutate { $0.title = "b" })
            #expect(store.currentState.title == "b")
            #expect(observed.state.title == "b")
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func leafReadDependsOnItsPathOnly() {
            let store = makeStore()
            let observed = store.viewStore()
            let title = track { _ = observed.state.title }
            let count = track { _ = observed.state.count }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(title.value == 0)
            #expect(count.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nestedReadsAreGranular() {
            let store = makeStore()
            let observed = store.viewStore()
            let position = track { _ = observed.state.transport.position }
            let playing = track { _ = observed.state.transport.isPlaying }
            store.dispatch(.mutate { $0.transport.position = 3 })
            #expect(position.value == 1)
            #expect(playing.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nodeHopsAndDirectPathsAreTheSameDependency() {
            let store = makeStore()
            let observed = store.viewStore()
            let viaNode = track { _ = observed.state.transport.position }
            let direct = track { _ = observed.read(\.transport.position) }
            store.dispatch(.mutate { $0.transport.position = 1 })
            #expect(viaNode.value == 1)
            #expect(direct.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func sameValueWriteDoesNotInvalidate() {
            let store = makeStore()
            let observed = store.viewStore()
            let title = track { _ = observed.state.title }
            store.dispatch(.mutate { $0.title = "a" })
            #expect(title.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func equatableNodeValueComparesWhole() {
            let store = makeStore()
            let observed = store.viewStore()
            let mixer = track { _ = observed.state.mixer.value }
            store.dispatch(.mutate { $0.mixer = Mixer() })
            #expect(mixer.value == 0)
            store.dispatch(.mutate { $0.mixer.muted = true })
            #expect(mixer.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func nonEquatableValueAlwaysCountsAsChanged() {
            let store = makeStore()
            let observed = store.viewStore()
            let opaque = track { _ = observed.state.opaque.value }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(opaque.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func wholeStateReadIsCoarse() {
            let store = makeStore()
            let observed = store.viewStore()
            let whole = track { _ = observed.state.value }
            store.dispatch(.mutate { $0.mixer.volume = 0.5 })
            #expect(whole.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func optionalPresenceDependsOnTheEdgeOnly() {
            let store = makeStore(Screen(detail: Transport()))
            let observed = store.viewStore()
            let present = track { _ = observed.state.detail.isPresent() }
            store.dispatch(.mutate { $0.detail?.position = 9 })
            #expect(present.value == 0)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(present.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func unwrappedNodeReadsThroughAndSurvivesNil() {
            let store = makeStore(Screen(detail: Transport(position: 2)))
            let observed = store.viewStore()
            let detail = observed.state.detail.unwrapped()
            #expect(detail?.position == 2)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(observed.state.detail.unwrapped() == nil)
            #expect(detail?.position == 2) // a lingering node reads its last-known value
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func hotAndColdRegionsAreIndependent() {
            let store = makeStore()
            let observed = store.viewStore()
            let ticks = 50
            var hot = 0
            var cold = 0
            for tick in 0..<ticks {
                let playhead = track { _ = observed.state.transport.position }
                let console = track {
                    _ = observed.state.mixer.volume
                    _ = observed.state.mixer.muted
                    _ = observed.state.title
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

    @Suite("ViewStore — each")
    @MainActor
    struct ViewStoreEachTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowsDependOnTheirOwnElement() {
            let store = makeStore()
            let observed = store.viewStore()
            let rows = observed.state.each(\.songs)
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
            let observed = store.viewStore()
            let content = track { _ = observed.state.each(\.songs) }
            store.dispatch(.mutate { $0.songs[0].title = "ONE" })
            #expect(content.value == 0)
            let membership = track { _ = observed.state.each(\.songs) }
            store.dispatch(.mutate { $0.songs.append(Song(id: 3, title: "three")) })
            #expect(membership.value == 1)
            let order = track { _ = observed.state.each(\.songs) }
            store.dispatch(.mutate { $0.songs.reverse() })
            #expect(order.value == 1)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowsFollowTheirElementAcrossReordersAndOutliveRemoval() {
            let store = makeStore()
            let observed = store.viewStore()
            let second = observed.state.each(\.songs)[1]
            store.dispatch(.mutate { $0.songs.reverse() })
            #expect(second.title == "two")
            store.dispatch(.mutate { $0.songs.removeAll { $0.id == 2 } })
            #expect(second.title == "two") // last-known value, no crash
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func rowPathsAreStableInstances() {
            let observed = makeStore().viewStore()
            let first = observed.state.each(\.songs).map(rowPath)
            let second = observed.state.each(\.songs).map(rowPath)
            #expect(first == second)
        }
    }

    // MARK: - Registry and notification gating

    @Suite("ViewStore — registry and gating")
    @MainActor
    struct ViewStoreRegistryTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func firedDependenciesDisarmUntilReadAgain() {
            let store = makeStore()
            let observed = store.viewStore()
            _ = track { _ = observed.state.title }
            _ = track { _ = observed.state.count }
            #expect(observed.testArmedCount == 2)
            store.dispatch(.mutate { $0.title = "b" })
            #expect(observed.testArmedCount == 1)
            _ = observed.state.title
            #expect(observed.testArmedCount == 2)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func ownObserversFireOnlyWhenTheSnapshotChanged() {
            let store = makeStore()
            let observed = store.viewStore()
            let counter = Counter()
            let (_, token) = observed.stateStream.subscribe { _ in counter.bump() }
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
                .viewStore()
            let baseline = maps.value
            store.dispatch(.mutate { $0.transport.position = 1 })
            for _ in 0..<10 { _ = observed.state.position }
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
                .viewStore()
            let baseline = maps.value
            store.dispatch(.mutate { $0.mixer.volume = 0 })
            store.dispatch(.mutate { $0.title = "z" })
            #expect(maps.value == baseline)
            store.dispatch(.mutate { $0.transport.position = 4 })
            #expect(maps.value == baseline + 1)
            #expect(observed.state.value == 4)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func featureFactoryBuffersEquatableState() {
            let store = makeStore()
            let maps = Counter()
            let observed = store
                .projection(action: { $0 }, state: \.transport)
                .featureProjection(
                    environment: (),
                    action: Reader { _ in { @Sendable action in action } },
                    state: Reader { _ in { (t: Transport) -> Double in maps.bump(); return t.position } }
                )
                .viewStore(.observation)
            let baseline = maps.value
            store.dispatch(.mutate { $0.count += 1 })
            #expect(maps.value == baseline)
            store.dispatch(.mutate { $0.transport.position = 2 })
            #expect(observed.state.value == 2)
        }
    }

    // MARK: - Scoped stores

    @Suite("ViewStore — focus")
    @MainActor
    struct ViewStoreFocusTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func focusReadsGranularlyAndDispatchesThroughItsLane() {
            let store = makeStore()
            let observed = store.viewStore()
            let transport = observed.focus(.state(\.transport), .action(review: ScreenAction.transport))
            let playing = track { _ = transport.state.isPlaying }
            let position = track { _ = transport.state.position }
            transport.dispatch(.play)
            #expect(store.currentState.transport.isPlaying)
            #expect(playing.value == 1)
            #expect(position.value == 0)
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func focusSupportsBindings() {
            let store = makeStore()
            let transport = store.viewStore().focus(.state(\.transport), .action(review: ScreenAction.transport))
            let playing = transport.binding(.state(\.isPlaying), dispatch: .action(review: { (_: Bool) in TransportAction.play }))
            #expect(playing.wrappedValue == false)
            playing.wrappedValue = true
            #expect(store.currentState.transport.isPlaying)
        }

        @Test func focusReadsThroughTheParentEngine() {
            let store = makeStore()
            let observed = store.viewStore(.combine)
            let transport = observed.focus(.state(\.transport), .action(review: ScreenAction.transport))
            #expect(transport.testSignal === observed.testSignal)
            _ = transport.state.position
            #expect(observed.testArmedCount == 1)   // the slice's read armed the parent's engine
            store.dispatch(.mutate { $0.transport.position = 5 })
            #expect(transport.state.position == 5)
        }

        @Test func focusStreamFollowsTheSlice() {
            let store = makeStore()
            let transport = store.viewStore(.combine).focus(.state(\.transport), .action(review: ScreenAction.transport))
            var received: [Double] = []
            let token = transport.stateStream.observe { received.append($0.position) }
            store.dispatch(.mutate { $0.transport.position = 2 })
            #expect(received == [0, 2])
            _ = token
        }
    }

    // MARK: - Transpose

    @Suite("ViewStore — transpose")
    @MainActor
    struct ViewStoreTransposeTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func optionalTransposeDependsOnThePresenceEdgeOnly() {
            let store = makeStore(Screen(detail: Transport(position: 1)))
            let observed = store.viewStore()
            let slot = observed.focus(.state(\.detail), .action(review: ScreenAction.transport))
            var child: StoreProjection<TransportAction, Transport>?
            let edge = track { child = slot.transpose() }
            var shown: [Double] = []
            let token = child?.stateStream.observe { shown.append($0.position) }   // the child screen's engine
            store.dispatch(.mutate { $0.detail?.position = 7 })
            #expect(edge.value == 0)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(edge.value == 1)
            #expect(slot.transpose() == nil)
            #expect(shown == [1, 7, 7])   // follows its own state, then holds the last present value
            _ = token
        }
    }

    // MARK: - Synchronous chain

    @Suite("ViewStore — synchronous chain")
    @MainActor
    struct ViewStoreSynchronousTests {
        @Test func dispatchSignalsTheViewInsideTheCallerTransaction() {
            let store = makeStore()
            let observed = store.projection(action: { $0 }, state: \.transport).buffer().viewStore(.combine)
            _ = observed.state.position
            var signalledInside = false
            let cancellable = observed.testSignal.objectWillChange.sink {
                signalledInside = true
            }
            withAnimation(.linear) {
                observed.dispatch(.mutate { $0.transport.position = 1 })
            }
            #expect(signalledInside)   // store → projection → buffer → engine, all inside withAnimation's transaction
            cancellable.cancel()
        }
    }

    // MARK: - Bindings

    @Suite("ViewStore — binding registration")
    @MainActor
    struct ViewStoreBindingTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func presenceDependsOnThePresenceEdge() {
            let store = makeStore(Screen(detail: Transport()))
            let observed = store.viewStore()
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
            let observed = store.viewStore()
            let presence = observed.presence(.state { $0.detail }, dismiss: .mutate { $0.detail = nil })
            let whole = track { _ = presence.wrappedValue }
            store.dispatch(.mutate { $0.count += 1 })
            #expect(whole.value == 1)
        }
    }

    // MARK: - Combine strategy

    @Suite("ViewStore — combine")
    @MainActor
    struct ViewStoreCombineTests {
        @Test func objectWillChangeOnlyWhenAReadPathChanged() {
            let store = makeStore()
            let observed = store.viewStore(.combine)
            let sends = Counter()
            let cancellable = observed.testSignal.objectWillChange.sink { sends.bump() }
            store.dispatch(.mutate { $0.count += 1 }) // nothing read yet
            #expect(sends.value == 0)
            _ = observed.state.title
            store.dispatch(.mutate { $0.count += 1 }) // unread path
            #expect(sends.value == 0)
            store.dispatch(.mutate { $0.title = "b" }) // read path
            #expect(sends.value == 1)
            store.dispatch(.mutate { $0.title = "c" }) // cleared until re-read by a render
            #expect(sends.value == 1)
            _ = observed.state.title
            store.dispatch(.mutate { $0.title = "d" })
            #expect(sends.value == 2)
            cancellable.cancel()
        }

        @Test func observationStrategyNeverSendsObjectWillChange() {
            guard #available(iOS 17, macOS 14, tvOS 17, watchOS 10, *) else { return }
            let store = makeStore()
            let observed = store.viewStore()
            let sends = Counter()
            let cancellable = observed.testSignal.objectWillChange.sink { sends.bump() }
            _ = observed.state.title
            store.dispatch(.mutate { $0.title = "b" })
            #expect(sends.value == 0)
            cancellable.cancel()
        }
    }

    // MARK: - Host

    @Suite("ProjectionKeeper")
    @MainActor
    struct ProjectionKeeperTests {
        @Test func boxBuildsOncePerId() {
            let store = makeStore()
            let makes = Counter()
            let box = ProjectionKeeper<ScreenAction, Screen, EmptyView>.Box()
            let make = { () -> ViewStoreEngine<ScreenAction, Screen> in
                makes.bump()
                return ViewStoreEngine(store, strategy: .combine)
            }
            let first = box.engine(id: nil, make: make)
            let again = box.engine(id: nil, make: make)
            #expect(first === again)
            #expect(makes.value == 1)
            let other = box.engine(id: 1, make: make)
            #expect(other !== first)
            #expect(makes.value == 2)
        }
    }
#endif
