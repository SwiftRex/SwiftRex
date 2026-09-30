// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// One name for everything SwiftUI takes as a `Binding` — `binding` — typed by what the SwiftUI parameter expects.
// Each slot is typed as the concrete capability witness it needs (a `Reads` for the state slice, an `Embeds` for
// the emitted action), so the slots can't be crossed and autocomplete offers only the right axis. Writes
// round-trip through a dispatched action — the reducer stays the only writer.
//
//   • `binding(.state(…), dispatch: .action(…))` — two-way `Binding<T>`, dispatches on every change:
//     `TextField`, `Toggle`, `NavigationStack(path:)`, `TabView(selection:)`.
//   • `binding(.state(\.optional), dismiss: action)` — presentation driven by state, the binding only dismisses:
//     `Binding<Bool>` for `isPresented:`, `Binding<T?>` for `item:` — whichever the SwiftUI parameter asks for.
//   • `binding(.state(\.presentation), dismiss: action)` — a `Binding<Presentation<T>>` carrying **both** dismiss
//     edges: hand it straight to `.sheet(item:)`, or take `.isPresented()` / `.item()` + `.onDismiss()` for any other
//     container.
//
// They live on `ViewStore`, not `StoreType`: a binding's getter must register what it reads so the view redraws
// when it changes, and only a view store can. A `.state(\.path)` lane registers exactly that path (and a
// `Binding<Bool>` only the presence edge); a closure/lens lane depends on the whole state.

extension ViewStore {
    /// A two-way `Binding<T>` from a **state read** and an **action embed** of the same value type — the one
    /// write-through binding. It dispatches on **every** change, so besides `TextField`/`Toggle`/sliders it
    /// also drives `NavigationStack(path:)` (`T == [Route]`) and `TabView(selection:)` (`T == Tab` / `Tab?`).
    ///
    /// ```swift
    /// TextField("Name", text: store.binding(.state(\.name), dispatch: .action(\.setName)))
    /// NavigationStack(path: store.binding(.state(\.path), dispatch: .action(\.setPath))) { root }
    /// TabView(selection: store.binding(.state(\.tab), dispatch: .action(\.selectTab))) { … }
    /// ```
    @MainActor
    public func binding<S: Relay.StateAxis.ReadsProtocol, A: Relay.ActionAxis.EmbedsProtocol>(
        _ state: Relay.Scope<Action, Relay.Absurd<Action>, State, S, Never, Relay.Absurd<Never>>,
        dispatch action: Relay.Scope<Action, A, State, Relay.Absurd<State>, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<S.Local> where S.Global == State, A.Global == Action, A.Local == S.Local {
        Binding(
            get: { self.read(state.state) },
            set: { self.dispatch(action.action.review($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }

    /// A `Binding<Bool>` that is `true` while the optional state slice is `.some`; setting `false`
    /// (SwiftUI dismissing) dispatches `dismiss`. Presentation is driven by state — the binding only
    /// dismisses. For `.sheet(isPresented:)` / `.fullScreenCover(isPresented:)` / alerts.
    @MainActor
    public func binding<Wrapped: Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Action, Relay.Absurd<Action>, State, S, Never, Relay.Absurd<Never>>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> where S.Global == State, S.Local == Wrapped? {
        Binding(
            get: { self.read(state.state, \Wrapped?.observationIsPresent) },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Item?>` for `.sheet(item:)` / `.popover(item:)` — present while the optional slice is
    /// `.some`; dispatch `dismiss` when SwiftUI clears it. SwiftUI keys the sheet on `Item.id`.
    @MainActor
    public func binding<Item: Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Action, Relay.Absurd<Action>, State, S, Never, Relay.Absurd<Never>>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Item?> where S.Global == State, S.Local == Item? {
        Binding(
            get: { self.read(state.state) },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Presentation<T>>` for a ``Presentation`` slice — the binding that carries **both** dismiss edges.
    /// A write that advances the stage dispatches `dismiss`, the single stage-dependent command
    /// (`presented → dismissing → dismissed`).
    ///
    /// Hand it straight to `.sheet(item:)` (for an `Identifiable` value), which wires both edges; for any other
    /// container take its parts:
    ///
    /// ```swift
    /// .sheet(item: viewStore.binding(.state(\.editor), dismiss: .editor(.dismiss))) { _ in
    ///     if let editor = viewStore.focus(.state(\.editor), .action(\.editor)).transpose() { EditorView(viewStore: editor) }
    /// }
    ///
    /// let cover = viewStore.binding(.state(\.editor), dismiss: .editor(.dismiss))
    /// .fullScreenCover(isPresented: cover.isPresented(), onDismiss: cover.onDismiss()) { … }
    /// ```
    ///
    /// There is deliberately no `Binding<Bool>` straight from a `Presentation` slice: SwiftUI's second edge
    /// (`onDismiss`, when the animation ends) must dispatch too, or the slot stays `dismissing` forever — the
    /// `Binding<Presentation<T>>` keeps both edges together.
    @MainActor
    public func binding<Wrapped: Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Action, Relay.Absurd<Action>, State, S, Never, Relay.Absurd<Never>>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Presentation<Wrapped>> where S.Global == State, S.Local == Presentation<Wrapped> {
        Binding(
            get: { self.read(state.state) },
            set: { newValue in
                // Only a write that advances the stage dismisses; a no-op write (SwiftUI re-affirming
                // `isPresented = true`) leaves the slot alone.
                guard newValue.stage != state.state.get(self.reader.peekWhole()).stage else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }
}
#endif
