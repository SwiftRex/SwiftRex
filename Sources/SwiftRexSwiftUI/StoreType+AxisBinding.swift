// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// The axis-separated store bindings — three verbs under one vocabulary. Each slot is typed as the concrete
// capability witness it needs (a `Reads` for the state slice, an `Embeds` for the emitted action), so the
// slots can't be crossed and autocomplete offers only the right axis: `.state(…)` carries every read strategy
// (key path / closure / lens), `.action(…)` every embed strategy (`\.case` / prism / review). Writes
// round-trip through a dispatched action — the reducer stays the only writer.
//
//   • `binding`  — two-way, dispatches on EVERY change. Subsumes what were once `path`/`selection`.
//   • `presence` — dismiss-only → `Binding<Bool>`   for `.sheet(isPresented:)` / alert / cover / popover.
//   • `item`     — dismiss-only → `Binding<Item?>`  for `.sheet(item:)` / `.popover(item:)`.
//
// `presence` and `item` each take EITHER a plain optional slice (1-stage) OR a `Presentation<Wrapped>` slice
// (3-stage, flicker-free) — the state shape you pass picks the behaviour, not a differently-named method.

extension StoreType {
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
        _ state: Relay.Scope<Relay.Absurd, S, Relay.Absurd>,
        dispatch action: Relay.Scope<A, Relay.Absurd, Relay.Absurd>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<S.L> where S.G == State, A.G == Action, A.L == S.L {
        Binding(
            get: { state.state.get(self.state) },
            set: { self.dispatch(action.action.review($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }

    /// A `Binding<Bool>` that is `true` while the optional state slice is `.some`; setting `false`
    /// (SwiftUI dismissing) dispatches `dismiss`. Presentation is driven by state — the binding only
    /// dismisses. For `.sheet(isPresented:)` / `.fullScreenCover(isPresented:)` / alerts.
    @MainActor
    public func presence<Wrapped: Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Relay.Absurd, S, Relay.Absurd>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> where S.G == State, S.L == Wrapped? {
        Binding(
            get: { state.state.get(self.state) != nil },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// The `Binding<Bool>` for a ``Presentation`` slice — `true` only while `.presented`. Setting `false`
    /// dispatches `dismiss` (`presented → dismissing`); the slice keeps rendering `dismissing(last:)` while
    /// SwiftUI animates out (flicker-free). Pair with an `onDismiss:` dispatching the same `dismiss`, or use
    /// the `presenting` view modifier, which wires both edges for you.
    @MainActor
    public func presence<Wrapped: Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Relay.Absurd, S, Relay.Absurd>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> where S.G == State, S.L == Presentation<Wrapped> {
        Binding(
            get: { state.state.get(self.state).isPresented },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Item?>` for `.sheet(item:)` / `.popover(item:)` — present while the optional slice is
    /// `.some`; dispatch `dismiss` when SwiftUI clears it. SwiftUI keys the sheet on `Item.id`.
    @MainActor
    public func item<Item: Identifiable & Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Relay.Absurd, S, Relay.Absurd>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Item?> where S.G == State, S.L == Item? {
        Binding(
            get: { state.state.get(self.state) },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// The `.sheet(item:)` binding for an `Identifiable` ``Presentation`` slice — `.some` only while
    /// `.presented` (entering `dismissing` flips it to `nil` so SwiftUI starts the out-animation); setting
    /// `nil` dispatches `dismiss`. The stable `Item.id` keeps the sheet put as the child state changes.
    @MainActor
    public func item<Wrapped: Identifiable & Sendable, S: Relay.StateAxis.ReadsProtocol>(
        _ state: Relay.Scope<Relay.Absurd, S, Relay.Absurd>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Wrapped?> where S.G == State, S.L == Presentation<Wrapped> {
        Binding(
            get: {
                let presentation = state.state.get(self.state)
                return presentation.isPresented ? presentation.wrapped : nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }
}
#endif
