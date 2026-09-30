// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    @testable import SwiftRex
    @testable import SwiftRexArchitecture
    import SwiftUI
    import Testing

    private struct Item: Sendable, Equatable, Identifiable {
        var id: Int
        var text: String
    }

    private enum BindAction: Sendable, Equatable { case modal(PresentationAction<Never>) }
    private struct BindState: Sendable, Equatable { var modal: Presentation<Item> = .dismissed }

    @MainActor
    private func makeStore(_ initial: Presentation<Item>) -> Store<BindAction, BindState, Void> {
        Store(
            initial: BindState(modal: initial),
            behavior: Behavior<BindAction, BindState, Void>.reduce { action, state in
                switch action {
                case .modal(.dismiss): state.modal = state.modal.dismiss()
                case .modal(.dismissed): state.modal = .dismissed
                }
            },
            environment: ()
        )
    }

    // Compile check for the documented spellings: `.sheet(item:)` straight from a `Binding<Presentation>`, and the
    // parts for any other container.
    private struct ModalHost: View {
        let viewStore: ViewStore<BindAction, BindState>

        var body: some View {
            let modal = viewStore.binding(.state(\.modal).action(review: BindAction.modal))
            Text("host")
                .sheet(item: viewStore.binding(.state(\.modal).action(review: BindAction.modal))) { item in Text(item.text) }
                .sheet(isPresented: modal.isPresented(), onDismiss: modal.onDismiss()) { Text("cover") }
                .popover(item: modal.item()) { item in Text(item.text) }
        }
    }

    @Suite("Presentation bindings")
    @MainActor
    struct PresentationBindingTests {
        @Test func isPresentedIsTrueOnlyWhilePresentedAndStartsTheDismissal() {
            let store = makeStore(.presented(Item(id: 1, text: "a")))
            let modal = store.viewStore().binding(.state(\.modal).action(review: BindAction.modal))
            #expect(modal.isPresented().wrappedValue == true)

            modal.isPresented().wrappedValue = false // SwiftUI starts dismissing → dismiss
            #expect(store.currentState.modal == .dismissing(last: Item(id: 1, text: "a")))
            #expect(modal.isPresented().wrappedValue == false) // false while dismissing
        }

        @Test func itemIsThePresentedValueAndStartsTheDismissal() {
            let store = makeStore(.presented(Item(id: 7, text: "x")))
            let modal = store.viewStore().binding(.state(\.modal).action(review: BindAction.modal))
            #expect(modal.item().wrappedValue == Item(id: 7, text: "x"))

            modal.item().wrappedValue = nil // SwiftUI clears the item → dismiss
            #expect(store.currentState.modal == .dismissing(last: Item(id: 7, text: "x")))
            #expect(modal.item().wrappedValue == nil) // nil while dismissing
        }

        @Test func aWriteThatDoesNotAdvanceTheStageIsIgnored() {
            let store = makeStore(.presented(Item(id: 4, text: "d")))
            let modal = store.viewStore().binding(.state(\.modal).action(review: BindAction.modal))
            modal.isPresented().wrappedValue = true // SwiftUI re-affirming: no dismissal
            #expect(store.currentState.modal == .presented(Item(id: 4, text: "d")))
        }

        @Test func documentedSpellingsBuild() {
            _ = ModalHost(viewStore: makeStore(.dismissed).viewStore()).body
        }

        @Test func onDismissCompletesTheDismissal() {
            let store = makeStore(.presented(Item(id: 2, text: "b")))
            let modal = store.viewStore().binding(.state(\.modal).action(review: BindAction.modal))
            modal.item().wrappedValue = nil // first edge: presented → dismissing
            modal.onDismiss()() // second edge, when the animation ends: dismissing → dismissed
            #expect(store.currentState.modal == .dismissed)
        }

        @Test func aProgrammaticDismissNeedsOnlyTheSecondEdge() {
            let store = makeStore(.presented(Item(id: 3, text: "c")))
            let modal = store.viewStore().binding(.state(\.modal).action(review: BindAction.modal))
            store.dispatch(.modal(.dismiss)) // the reducer starts it: presented → dismissing
            #expect(modal.item().wrappedValue == nil)
            modal.onDismiss()()
            #expect(store.currentState.modal == .dismissed)
        }
    }
#endif
