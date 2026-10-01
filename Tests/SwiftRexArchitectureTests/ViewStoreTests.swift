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
        @Test func transposedPositionReadsThroughAndSurvivesNil() {
            let store = makeStore(Screen(detail: Transport(position: 2)))
            let observed = store.viewStore()
            let detail = observed.state.detail.transpose()
            #expect(detail?.position == 2)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(observed.state.detail.transpose() == nil)
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
        @Test func itsStreamIsThePureUpstreamNotTheSnapshot() {
            // Followers of a view store follow its upstream: every upstream state reaches them, whatever the snapshot's
            // diff decided — observation stays out of composition. (Dedupe with a `buffer()` where it matters.)
            let store = makeStore()
            let observed = store.viewStore()
            let counter = Counter()
            let (_, token) = observed.stateStream.subscribe { _ in counter.bump() }
            store.dispatch(.mutate { $0.title = "a" }) // equal state: the store still delivers it
            #expect(counter.value == 1)
            store.dispatch(.mutate { $0.title = "b" })
            #expect(counter.value == 2)
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

    // MARK: - Deriving a child — a pure stage, owned by whoever observes it

    @Suite("ViewStore — deriving a child")
    @MainActor
    struct ViewStoreChildTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func aProjectedChildIsItsOwnViewStoreWithItsOwnSnapshot() {
            let store = makeStore()
            let parent = store.viewStore(.observation)
            let child = parent.projection(.action(review: ScreenAction.transport).state(\.transport)).viewStore(.observation)
            #expect(child.testSignal !== parent.testSignal)             // its own engine, owned by the test
            let playing = track { _ = child.state.isPlaying }
            let position = track { _ = child.state.position }
            child.dispatch(.play)                                        // through the lane, into the store
            #expect(store.currentState.transport.isPlaying)
            #expect(playing.value == 1)
            #expect(position.value == 0)
            #expect(parent.testArmedCount == 0)                         // the child's reads never touch the parent
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func aChildSupportsBindings() {
            let store = makeStore()
            let child = store.viewStore().projection(.action(review: ScreenAction.transport).state(\.transport)).viewStore()
            let playing = child.binding(.state(\.isPlaying).action(review: { (_: Bool) in TransportAction.play }))
            #expect(playing.wrappedValue == false)
            playing.wrappedValue = true
            #expect(store.currentState.transport.isPlaying)
        }

        @Test func deriving_followsThePureSideNotTheSnapshot() {
            // The parent view store has read nothing, so its snapshot diff would signal nothing — a child that followed
            // the snapshot would miss changes. A child derived from it follows the upstream chain, so it sees them all.
            let store = makeStore()
            let parent = store.viewStore(.combine)
            let sends = Counter()
            let cancellable = parent.testSignal.objectWillChange.sink { sends.bump() }
            var received: [Double] = []
            let token = parent.projection(action: { $0 }, state: \.transport.position).stateStream.observe { received.append($0) }
            store.dispatch(.mutate { $0.transport.position = 2 })
            store.dispatch(.mutate { $0.transport.position = 3 })
            #expect(received == [0, 2, 3])
            #expect(sends.value == 0)                                    // and the parent was never signalled
            cancellable.cancel()
            _ = token
        }

        @Test func theParentKeepsNothingForItsChildren() {
            let store = makeStore()
            let parent = store.viewStore(.combine)
            var children = (0..<50).map { _ in parent.projection(.action(review: ScreenAction.transport).state(\.transport)).viewStore(.combine) }
            children.forEach { _ = $0.state.position }
            #expect(parent.testArmedCount == 0)
            children.removeAll()                                         // children go; the parent is untouched
            store.dispatch(.mutate { $0.transport.position = 9 })
            #expect(parent.state.transport.position == 9)
        }
    }

    // MARK: - Transpose

    @Suite("ViewStore — transpose")
    @MainActor
    struct ViewStoreTransposeTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func optionalTransposeDependsOnTheEdgeAndGivesAPureStage() {
            let store = makeStore(Screen(detail: Transport(position: 1)))
            let parent = store.viewStore(.observation)
            var slot: StoreOptionalFocus<TransportAction, Transport>?
            let edge = track { slot = parent.transpose(.action(review: ScreenAction.transport).state(\.detail)) }
            let child = slot?.viewStore(.observation)                   // the owner — here, the test
            #expect(child?.testSignal !== parent.testSignal)
            let position = track { _ = child?.state.position }
            store.dispatch(.mutate { $0.detail?.isPlaying = true })     // the child's sibling field
            #expect(position.value == 0)
            #expect(edge.value == 0)
            store.dispatch(.mutate { $0.detail?.position = 7 })
            #expect(edge.value == 0)                                   // the parent depends on the edge only
            #expect(position.value == 1)
            store.dispatch(.mutate { $0.detail = nil })
            #expect(edge.value == 1)
            #expect(parent.transpose(.action(review: ScreenAction.transport).state(\.detail)) == nil)
            #expect(child?.state.position == 7)                        // holds the last present value
        }

        @Test func aTransposedStageHoldsTheLastPresentValue() {
            let store = makeStore(Screen(detail: Transport(position: 1)))
            let child = store.viewStore(.combine).transpose(.action(review: ScreenAction.transport).state(\.detail))
            var shown: [Double] = []
            let token = child?.stateStream.observe { shown.append($0.position) }
            store.dispatch(.mutate { $0.detail?.position = 7 })
            store.dispatch(.mutate { $0.detail = nil })
            #expect(shown == [1, 7, 7])
            _ = token
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func presentationTransposeIsPresentWhileDismissing() {
            let store = makePresentationStore(.presented(Transport(position: 4)))
            let parent = store.viewStore()
            var slot: StoreOptionalFocus<PresentationAction<TransportAction>, Transport>?
            let edge = track { slot = parent.transpose(.action(review: PAction.editor).state(\.editor)) }
            let child = slot?.viewStore()
            store.dispatch(.editor(.dismiss))                           // presented → dismissing: still present
            #expect(edge.value == 0)
            #expect(child?.state.position == 4)
            store.dispatch(.editor(.dismissed))                         // the animation ended → dismissed
            #expect(edge.value == 1)
            #expect(parent.transpose(.action(review: PAction.editor).state(\.editor)) == nil)
            #expect(child?.state.position == 4)
        }
    }

    private struct PState: Sendable, Equatable { var editor: Presentation<Transport> }
    private enum PAction: Sendable { case editor(PresentationAction<TransportAction>) }

    @MainActor
    private func makePresentationStore(_ editor: Presentation<Transport>) -> Store<PAction, PState, Void> {
        Store(
            initial: PState(editor: editor),
            behavior: Reducer.reduce { (action: PAction, state: inout PState) in
                switch action {
                case .editor(.dismiss): state.editor = state.editor.dismiss()
                case .editor(.dismissed): state.editor = .dismissed
                case .editor(.child): break
                }
            }.asBehavior(),
            environment: ()
        )
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

    @Suite("ViewStore — binding writes")
    @MainActor
    struct ViewStoreBindingWriteTests {
        @Test func anEqualWriteDispatchesNothing() {
            let store = makeStore()
            // A deliberately non-idempotent lane: every dispatch bumps `count`, whatever the value.
            let count = store.viewStore(.combine).binding(.state(\.count).action(review: { (_: Int) in ScreenAction.mutate { $0.count += 1 } }))
            count.wrappedValue = 0 // equal to the current value (0): SwiftUI re-writing it
            count.wrappedValue = 0
            #expect(store.currentState.count == 0) // swiftlint:disable:this empty_count
            count.wrappedValue = 7 // a real change: one dispatch
            #expect(store.currentState.count == 1)
            count.wrappedValue = 1 // equal to the current value (now 1): nothing
            #expect(store.currentState.count == 1)
        }
    }

    @Suite("ViewStore — binding registration")
    @MainActor
    struct ViewStoreBindingTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func presenceDependsOnThePresenceEdge() {
            let store = makeStore(Screen(detail: Transport()))
            let observed = store.viewStore()
            let presence: Binding<Bool> = observed.binding(.state(\.detail).action(review: { (_: Void) in .mutate { $0.detail = nil } }))
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
            let presence: Binding<Bool> = observed.binding(.state { $0.detail }.action(review: { (_: Void) in .mutate { $0.detail = nil } }))
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
            let make = { () -> ViewStore<ScreenAction, Screen> in
                makes.bump()
                return store.viewStore(.combine)
            }
            let first = box.viewStore(id: nil, make: make)
            let again = box.viewStore(id: nil, make: make)
            #expect(first.testSignal === again.testSignal)
            #expect(makes.value == 1)
            let other = box.viewStore(id: 1, make: make)
            #expect(other.testSignal !== first.testSignal)
            #expect(makes.value == 2)
        }
    }

    // MARK: - Making a view store is explicit

    @Suite("ViewStore — .viewStore()")
    @MainActor
    struct MakingAViewStoreTests {
        @Test func aPlainStoreGetsItsOwnEngine() {
            let owned = makeStore().viewStore(.combine)
            #expect(owned.testArmedCount == 0)                       // a root view store over its own engine
            #expect(owned.state.title == "a")
        }

        @Test func onAViewStoreItMakesANewOneOverThePureUpstream() {
            let store = makeStore()
            let parent = store.viewStore(.combine)
            let child = parent.viewStore(.combine)
            #expect(child.testSignal !== parent.testSignal)          // its own engine and snapshot
            store.dispatch(.mutate { $0.title = "b" })
            #expect(child.state.title == "b")
        }

        @Test func aDerivedChildGetsItsOwnEngine() {
            // A router hands a feature's view a transposed child of its view store: a pure stage, made into its own
            // view store — every view store owns its snapshot.
            let parent = makeStore(Screen(detail: Transport(position: 1))).viewStore(.combine)
            let child = parent.transpose(.action(review: ScreenAction.transport).state(\.detail))?.viewStore(.combine)
            #expect(child?.testSignal !== parent.testSignal)
            #expect(child?.state.position == 1)
        }

        @Test func anExistentialStoreMakesOne() {
            let store: any StoreType<ScreenAction, Screen> = makeStore()
            #expect(store.viewStore(.combine).state.title == "a")
        }
    }
#endif
