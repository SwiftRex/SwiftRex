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

    private enum BindAction: Sendable, Equatable { case dismiss }
    private struct BindState: Sendable, Equatable { var modal: Presentation<Item> = .dismissed }

    @MainActor
    private func makeStore(_ initial: Presentation<Item>) -> Store<BindAction, BindState, Void> {
        Store(
            initial: BindState(modal: initial),
            behavior: Behavior<BindAction, BindState, Void>.reduce { action, state in
                switch action {
                case .dismiss: state.modal = state.modal.dismiss()
                }
            },
            environment: ()
        )
    }

    @Suite("Presentation bindings")
    @MainActor
    struct PresentationBindingTests {
        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func boolBindingIsPresentedAndDismisses() {
            let store = makeStore(.presented(Item(id: 1, text: "a")))
            #expect(store.presence(.state(\.modal), dismiss: .dismiss).wrappedValue == true)

            store.presence(.state(\.modal), dismiss: .dismiss).wrappedValue = false // set(false) → dismiss
            #expect(store.state.modal == .dismissing(last: Item(id: 1, text: "a")))
            #expect(store.presence(.state(\.modal), dismiss: .dismiss).wrappedValue == false)   // false while dismissing
        }

        @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
        @Test func itemBindingKeysOnPresentedThenDismisses() {
            let store = makeStore(.presented(Item(id: 7, text: "x")))
            #expect(store.item(.state(\.modal), dismiss: .dismiss).wrappedValue == Item(id: 7, text: "x"))

            store.item(.state(\.modal), dismiss: .dismiss).wrappedValue = nil // set(nil) → dismiss
            #expect(store.state.modal == .dismissing(last: Item(id: 7, text: "x")))
            #expect(store.item(.state(\.modal), dismiss: .dismiss).wrappedValue == nil)   // nil while dismissing
        }
    }
#endif
