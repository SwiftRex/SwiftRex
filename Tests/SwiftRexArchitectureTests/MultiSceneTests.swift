// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    import CoreFP
    @testable import SwiftRex
    @testable import SwiftRexArchitecture
    import SwiftUI
    import Testing

    // Proves multi-scene is single-store: open scenes are STATE (a dictionary of per-scene sub-states),
    // each window projects its slice by id, and a `some Scene` body wires WindowGroup(for:) to the one
    // store. No new projection machinery — the existing dictionary projection carries the per-scene slice.

    private struct DocState: Sendable, Equatable { var title: String; var edits = 0 }
    private enum DocAction: Sendable, Equatable { case bumpEdits }

    // @Prisms requires >= fileprivate.
    // swiftlint:disable private_over_fileprivate
    @Prisms
    fileprivate enum SceneAppAction: Sendable {
        case open(Int, String)
        case close(Int)
        case document(ElementAction<Int, DocAction>)
    }

    @Lenses
    fileprivate struct SceneAppState: Sendable {
        var documents: [Int: DocState] = [:] // open windows, keyed by id
    }

    // swiftlint:enable private_over_fileprivate

    @Suite("Multi-scene single store")
    @MainActor
    struct MultiSceneTests {
        private func makeStore() -> Store<SceneAppAction, SceneAppState, Void> {
            Store(
                initial: SceneAppState(),
                behavior: Reducer.reduce { (action: SceneAppAction, state: inout SceneAppState) in
                    switch action {
                    case let .open(id, title): state.documents[id] = DocState(title: title)
                    case let .close(id): state.documents[id] = nil
                    case let .document(elem):
                        switch elem.action {
                        case .bumpEdits: state.documents[elem.id]?.edits += 1
                        }
                    }
                }.asBehavior(),
                environment: ()
            )
        }

        @Test func openAndCloseScenesAreStateInTheOneStore() {
            let store = makeStore()
            store.dispatch(.open(1, "A"))
            store.dispatch(.open(2, "B"))
            #expect(store.state.documents.count == 2)
            store.dispatch(.close(1))
            #expect(store.state.documents[1] == nil)
            #expect(store.state.documents[2]?.title == "B")
        }

        @available(iOS 16.1, macOS 13, tvOS 16.1, watchOS 9.1, *)
        @Test func hasSceneReflectsOpenWindows() {
            let store = makeStore()
            store.dispatch(.open(7, "Doc"))
            #expect(store.hasScene(7, in: \.documents))
            #expect(!store.hasScene(9, in: \.documents))
        }

        @Test func perSceneProjectionCarriesTheSlice() {
            let store = makeStore()
            store.dispatch(.open(3, "C"))
            // Each window projects its own slice by id — the existing dictionary projection.
            let window = store.projection(
                key: 3,
                actionReview: SceneAppAction.document,
                stateDictionary: \.documents
            )
            #expect(window.state?.title == "C")
            window.dispatch(.bumpEdits) // dispatches into the ONE store, scoped to id 3
            #expect(store.state.documents[3]?.edits == 1)
        }
    }

    // Compile-proof: a `some Scene` body wires WindowGroup(for:) to the single store, projecting each
    // window's slice by id. Not runtime-tested (Scenes are app-level), but compiling proves the pattern.
    @available(iOS 16.1, macOS 13, tvOS 16.1, watchOS 9.1, *)
    @MainActor
    private func multiSceneBody(store: Store<SceneAppAction, SceneAppState, Void>) -> some Scene {
        WindowGroup(for: Int.self) { $id in
            if let id, let doc = store.state.documents[id] {
                Text(doc.title) // real apps build the scene's feature view here
            }
        }
    }
#endif
