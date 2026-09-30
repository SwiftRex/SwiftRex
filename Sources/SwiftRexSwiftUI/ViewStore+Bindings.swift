// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// One name for everything SwiftUI takes as a `Binding`: `binding`, taking the same chained scope as `focus` and
// `projection` — a `.state(…)` lane to read and an `.action(…)` lane to dispatch. What the action lane embeds
// decides the kind of binding:
//
//   • `.state(\.name).action(\.setName)`       — the lane embeds the value: two-way `Binding<T>`, dispatching on
//     every change (`TextField`, `Toggle`, `NavigationStack(path:)`, `TabView(selection:)`).
//   • `.state(\.deleting).action(\.cancelDelete)` — an optional slot and a no-payload case: dismiss-only,
//     `Binding<Bool>` for `isPresented:` or `Binding<T?>` for `item:` — whichever the SwiftUI parameter asks for.
//   • `.state(\.editor).action(\.editor)`      — a `Presentation` slot and its `PresentationAction`: a
//     `Binding<Presentation<T>>` carrying **both** dismissal edges (`.dismiss`, then `.dismissed`). Hand it straight
//     to `.sheet(item:)`, or take `.isPresented()` / `.item()` + `.onDismiss()` for any other container.
//
// Writes round-trip through a dispatched action — the reducer stays the only writer. Bindings live on `ViewStore`,
// not `StoreType`: a binding's getter must register what it reads so the view redraws when it changes, and only a
// view store can. A key-path `.state(\.path)` lane registers exactly that path (and a `Binding<Bool>` only the
// presence edge); a closure/lens lane depends on the whole state.

extension ViewStore {
    /// A two-way `Binding<T>` — the action lane embeds the value the state lane reads, so every change dispatches
    /// it: `TextField`/`Toggle`/sliders, `NavigationStack(path:)` (`T == [Route]`), `TabView(selection:)`.
    ///
    /// ```swift
    /// TextField("Name", text: viewStore.binding(.state(\.name).action(\.setName)))
    /// NavigationStack(path: viewStore.binding(.state(\.path).action(\.setPath))) { root }
    /// ```
    @MainActor
    public func binding<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<S.Local> where A.Global == Action, S.Global == State, A.Local == S.Local {
        let reads = scope.state
        let review = scope.action.review
        return Binding(
            get: { self.read(reads) },
            set: { self.dispatch(review($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }

    /// A two-way `Binding<T>` for an `Equatable` value — the same as the general form, except that a write equal to
    /// the current value dispatches **nothing**. SwiftUI sometimes writes a binding more than once for one gesture
    /// (a list row tap writes its selection twice), so without this a reducer that isn't idempotent — a counter, a
    /// toggle, an "append to history" — would run twice.
    ///
    /// ```swift
    /// List(selection: viewStore.binding(.state(\.selection).action(\.select))) { … }   // one `.select` per tap
    /// ```
    @MainActor
    public func binding<A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<S.Local> where A.Global == Action, S.Global == State, A.Local == S.Local, S.Local: Equatable {
        let reads = scope.state
        let review = scope.action.review
        return Binding(
            get: { self.read(reads) },
            set: { newValue in
                guard newValue != reads.get(self.reader.peekWhole()) else { return }
                self.dispatch(review(newValue), source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A dismiss-only `Binding<Bool>` for an optional slot — `true` while it's `.some`; SwiftUI setting `false`
    /// dispatches the action lane's no-payload case. Presentation is driven by state; the binding only dismisses.
    /// For `isPresented:` parameters (sheets, covers, alerts, `navigationDestination(isPresented:)`). Depends on the
    /// presence edge only.
    ///
    /// ```swift
    /// .alert("Delete?", isPresented: viewStore.binding(.state(\.deleting).action(\.cancelDelete)),
    ///        presenting: viewStore.state.deleting.value) { … }
    /// ```
    @MainActor
    public func binding<Wrapped: Sendable, A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> where A.Global == Action, S.Global == State, S.Local == Wrapped?, A.Local == Void {
        let reads = scope.state
        let review = scope.action.review
        return Binding(
            get: { self.read(reads, \Wrapped?.observationIsPresent) },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(review(()), source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A dismiss-only `Binding<T?>` for an optional slot — the value while `.some`; SwiftUI setting `nil` dispatches
    /// the action lane's no-payload case. For `item:` parameters (SwiftUI keys the sheet on `T.id`).
    ///
    /// ```swift
    /// .sheet(item: viewStore.binding(.state(\.sharing).action(\.doneSharing))) { payload in ShareSheet(payload) }
    /// ```
    @MainActor
    public func binding<Wrapped: Sendable, A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Wrapped?> where A.Global == Action, S.Global == State, S.Local == Wrapped?, A.Local == Void {
        let reads = scope.state
        let review = scope.action.review
        return Binding(
            get: { self.read(reads) },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(review(()), source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Presentation<T>>` for a ``Presentation`` slot and its ``PresentationAction`` — the binding that
    /// carries **both** dismissal edges: the start (`presented → dismissing`) dispatches `.dismiss`, the end
    /// (SwiftUI's `onDismiss`) dispatches `.dismissed`. A write that doesn't move the stage dispatches nothing.
    ///
    /// Hand it straight to `.sheet(item:)` (for an `Identifiable` value), which wires both edges; for any other
    /// container take its parts:
    ///
    /// ```swift
    /// .sheet(item: viewStore.binding(.state(\.editor).action(\.editor))) { _ in
    ///     if let editor = viewStore.transpose(.action(\.editor.child).state(\.editor)) {
    ///         ProjectionKeeper { editor.viewStore() } content: { EditorView(viewStore: $0) }
    ///     }
    /// }
    ///
    /// let cover = viewStore.binding(.state(\.editor).action(\.editor))
    /// .fullScreenCover(isPresented: cover.isPresented(), onDismiss: cover.onDismiss()) { … }
    /// ```
    ///
    /// There is deliberately no `Binding<Bool>` straight from a `Presentation` slot: without its second edge
    /// (`onDismiss`) the slot would stay `dismissing` forever.
    @MainActor
    public func binding<Wrapped: Sendable, Child, A: Relay.ActionAxis.EmbedsProtocol, S: Relay.StateAxis.ReadsProtocol>(
        _ scope: Relay.Scope<Action, A, State, S, Never, Relay.Absurd<Never>>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Presentation<Wrapped>>
    where A.Global == Action, S.Global == State, S.Local == Presentation<Wrapped>, A.Local == PresentationAction<Child> {
        let reads = scope.state
        let review = scope.action.review
        return Binding(
            get: { self.read(reads) },
            set: { newValue in
                let source = ActionSource(file: file, function: function, line: line)
                switch (reads.get(self.reader.peekWhole()), newValue) {
                case (.presented, .dismissing): self.dispatch(review(.dismiss), source: source)
                case (.presented, .dismissed), (.dismissing, .dismissed): self.dispatch(review(.dismissed), source: source)
                default: break
                }
            }
        )
    }
}
#endif
