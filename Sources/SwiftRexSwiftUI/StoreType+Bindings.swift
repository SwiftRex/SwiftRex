#if canImport(SwiftUI)
import SwiftRex
import SwiftUI

// MARK: - Store-backed SwiftUI bindings
//
// These bridge a unidirectional ``StoreType`` to SwiftUI's *native* two-way modifiers — no new
// navigation dialect. Reads come from `store.state`; writes dispatch an ``Action``. Presentation is
// state-driven: the presence/item bindings only ever dispatch a *dismiss* (SwiftUI clearing the
// value); they never drive presentation from the binding, so `showing` is always a function of state.
//
//     // TextField:            TextField("Name", text: store.binding(\.name, set: Action.setName))
//     // Push (NavigationStack): NavigationStack(path: store.binding(\.path, set: Action.setPath)) { … }
//     // Sheet (isPresented):   .sheet(isPresented: store.presence(\.editor, dismiss: .dismissEditor)) { … }
//     // Sheet (item):          .sheet(item: store.item(\.selected, dismiss: .deselect)) { item in … }

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension StoreType {
    /// A two-way `Binding` that reads `state[keyPath:]` and dispatches `set(newValue)` on write.
    ///
    /// The general form under every navigation binding: use it directly for `TextField`,
    /// `NavigationStack(path:)`, `TabView(selection:)`, `Toggle`, sliders — anything with a
    /// `Binding`, where a write maps to a state-setting `Action`.
    @MainActor
    public func binding<Value>(
        _ keyPath: KeyPath<State, Value>,
        set: @escaping @Sendable (Value) -> Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Value> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.dispatch(set($0), source: ActionSource(file: file, function: function, line: line)) }
        )
    }

    /// A `Binding<Bool>` that is `true` while the optional sub-state at `keyPath` is `.some`.
    ///
    /// Setting it to `false` — SwiftUI dismissing — dispatches `dismiss`. It never sets `true`:
    /// presentation is driven by state (dispatch whatever action makes the sub-state `.some`), not
    /// by the binding. For `.sheet(isPresented:)`, `.fullScreenCover(isPresented:)`, alerts, etc.
    @MainActor
    public func presence<Wrapped>(
        _ keyPath: KeyPath<State, Wrapped?>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Bool> {
        Binding(
            get: { self.state[keyPath: keyPath] != nil },
            set: { isPresented in
                guard !isPresented else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<Item?>` for `.sheet(item:)` / `.popover(item:)` / `.fullScreenCover(item:)` —
    /// present while the sub-state is `.some`, and dispatch `dismiss` when SwiftUI clears it.
    @MainActor
    public func item<Item: Identifiable>(
        _ keyPath: KeyPath<State, Item?>,
        dismiss: Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Item?> {
        Binding(
            get: { self.state[keyPath: keyPath] },
            set: { newValue in
                guard newValue == nil else { return }
                self.dispatch(dismiss, source: ActionSource(file: file, function: function, line: line))
            }
        )
    }

    /// A `Binding<[Element]>` for `NavigationStack(path:)` — the **stack** navigation shape.
    ///
    /// SwiftUI hands the binding the *whole* new path on every structural change, so a single
    /// `set` action carries push (append), pop / back-swipe (truncate), and pop-to-root (empty)
    /// uniformly. The stack is a function of state; the reducer decides what a new path means
    /// (see the navigation reducer for standard `push`/`pop`/`setPath` handling).
    ///
    /// ```swift
    /// NavigationStack(path: store.path(\.path, set: NavAction.setPath)) { root }
    ///     .navigationDestination(for: Route.self) { route in router.view(for: route) }
    /// ```
    @MainActor
    public func path<Element>(
        _ keyPath: KeyPath<State, [Element]>,
        set: @escaping @Sendable ([Element]) -> Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<[Element]> {
        binding(keyPath, set: set, file: file, function: function, line: line)
    }

    /// A `Binding<Value>` for `TabView(selection:)` / `TabView(.page)` / carousels — the **selection**
    /// shape (exactly one of N, all children alive).
    ///
    /// Unlike ``presence(_:dismiss:)`` / ``item(_:dismiss:)`` (which only dispatch on *dismiss*),
    /// selection dispatches on **every** change — picking a tab is a real state transition the
    /// reducer honors (and may veto/redirect).
    ///
    /// ```swift
    /// TabView(selection: store.selection(\.tab, set: AppAction.selectTab)) { … }
    /// ```
    @MainActor
    public func selection<Value>(
        _ keyPath: KeyPath<State, Value>,
        set: @escaping @Sendable (Value) -> Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Value> {
        binding(keyPath, set: set, file: file, function: function, line: line)
    }

    /// A `Binding<Value?>` for `NavigationSplitView`-style **optional** selection (nothing selected
    /// yet, or a cleared sidebar). Dispatches on every change, including selecting `nil`.
    @MainActor
    public func selection<Value>(
        _ keyPath: KeyPath<State, Value?>,
        set: @escaping @Sendable (Value?) -> Action,
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) -> Binding<Value?> {
        binding(keyPath, set: set, file: file, function: function, line: line)
    }
}
#endif
