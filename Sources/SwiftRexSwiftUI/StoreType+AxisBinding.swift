// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// The axis-separated store bindings — the single implementation under the whole family. Each slot is typed
// as the concrete capability witness it needs (a `Reads` for the state slice, an `Embeds` for the emitted
// action), so the slots can't be crossed and autocomplete offers only the right axis: `.state(…)` carries
// every read strategy (key path / closure / lens), `.action(…)` every embed strategy (`\.case` / prism /
// review). Writes round-trip through a dispatched action — the reducer stays the only writer. The terse
// key-path spellings in `StoreType+Bindings.swift` delegate here.

extension StoreType {
    /// A two-way `Binding<T>` built from a **state read** and an **action embed** of the same value type —
    /// for `TextField`, `Toggle`, sliders, `NavigationStack(path:)`, `TabView(selection:)`, anything.
    ///
    /// ```swift
    /// TextField("Name", text: store.binding(.state(\.name), dispatch: .action(\.setName)))
    /// ```
    @MainActor
    public func binding<T: Sendable>(
        _ state: Relay.StateAxis.Reads<State, T>,
        dispatch action: Relay.ActionAxis.Embeds<Action, T>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<T> {
        Binding(
            get: { state.get(self.state) },
            set: { self.dispatch(action.review($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }

    /// A `Binding<Bool>` that is `true` while the optional state slice is `.some`; setting `false`
    /// (SwiftUI dismissing) dispatches `dismiss`. Presentation is driven by state — the binding only
    /// dismisses. For `.sheet(isPresented:)` / `.fullScreenCover(isPresented:)` / alerts.
    @MainActor
    public func presence<Wrapped: Sendable>(
        _ state: Relay.StateAxis.Reads<State, Wrapped?>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> {
        Binding(
            get: { state.get(self.state) != nil },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Item?>` for `.sheet(item:)` / `.popover(item:)` — present while the optional slice is
    /// `.some`; dispatch `dismiss` when SwiftUI clears it.
    @MainActor
    public func item<Item: Identifiable & Sendable>(
        _ state: Relay.StateAxis.Reads<State, Item?>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Item?> {
        Binding(
            get: { state.get(self.state) },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Bool>` for a ``Presentation`` slice — `true` only while `.presented`. Setting `false`
    /// dispatches `dismiss` (`presented → dismissing`); the slice keeps rendering `dismissing(last:)` while
    /// SwiftUI animates out. Pair with an `onDismiss:` dispatching the same `dismiss`, or use `presenting`.
    @MainActor
    public func presentation<Wrapped: Sendable>(
        _ state: Relay.StateAxis.Reads<State, Presentation<Wrapped>>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> {
        Binding(
            get: { state.get(self.state).isPresented },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Wrapped?>` for an `Identifiable` ``Presentation`` slice — `.some` only while `.presented`
    /// (entering `dismissing` flips it to `nil` so SwiftUI starts the out-animation); setting `nil`
    /// dispatches `dismiss`. Give it a **stable** id so the sheet stays put as the child state changes.
    @MainActor
    public func presentationItem<Wrapped: Identifiable & Sendable>(
        _ state: Relay.StateAxis.Reads<State, Presentation<Wrapped>>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Wrapped?> {
        Binding(
            get: {
                let presentation = state.get(self.state)
                return presentation.isPresented ? presentation.wrapped : nil
            },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<[Element]>` for `NavigationStack(path:)` — SwiftUI hands the whole new path on every
    /// structural change (push / pop / pop-to-root), so one dispatched action carries all of them.
    ///
    /// ```swift
    /// NavigationStack(path: store.path(.state(\.path), dispatch: .action(\.setPath))) { root }
    /// ```
    @MainActor
    public func path<Element: Sendable>(
        _ state: Relay.StateAxis.Reads<State, [Element]>,
        dispatch action: Relay.ActionAxis.Embeds<Action, [Element]>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<[Element]> {
        binding(state, dispatch: action, file: file, function: function, line: line)
    }

    /// A `Binding<Value>` for `TabView(selection:)` / carousels — the **selection** shape (1-of-N, all
    /// children alive). Dispatches on **every** change, unlike the dismiss-only presence/item bindings.
    ///
    /// ```swift
    /// TabView(selection: store.selection(.state(\.tab), dispatch: .action(\.selectTab))) { … }
    /// ```
    @MainActor
    public func selection<Value: Sendable>(
        _ state: Relay.StateAxis.Reads<State, Value>,
        dispatch action: Relay.ActionAxis.Embeds<Action, Value>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Value> {
        binding(state, dispatch: action, file: file, function: function, line: line)
    }

    /// A `Binding<Value?>` for `NavigationSplitView`-style **optional** selection. Dispatches on every
    /// change, including selecting `nil`.
    @MainActor
    public func selection<Value: Sendable>(
        _ state: Relay.StateAxis.Reads<State, Value?>,
        dispatch action: Relay.ActionAxis.Embeds<Action, Value?>,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Value?> {
        binding(state, dispatch: action, file: file, function: function, line: line)
    }
}
#endif
