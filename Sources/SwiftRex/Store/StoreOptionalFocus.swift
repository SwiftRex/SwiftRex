// SPDX-License-Identifier: Apache-2.0

/// A store of `T` over a store of `T?` — a pure stage that **holds the last present value** once the upstream reads
/// `nil`. For a child screen that exists while its value does and keeps showing what it showed while it animates away.
///
/// ```swift
/// if let editor = state.editor {                         // presence decided by whoever reads the state
///     let editorStore = StoreOptionalFocus(store.projection(action: AppAction.editor, state: \.editor), present: editor)
///     presentEditor(editorStore)
/// }
/// ```
///
/// It decides nothing about presence — deciding is a read, done by the view layer (`viewStore.traverse(…)` in
/// SwiftUI returns one of these) or by code following the parent's state. `present` is the value to start from.
/// Each observer remembers its own last present value.
@MainActor
public struct StoreOptionalFocus<Action: Sendable, State: Sendable>: StoreType {
    /// The wrapped value over time, holding the last present one while the upstream reads `nil`.
    public let stateStream: StateStream<State>
    private let _dispatch: @MainActor @Sendable (Action, ActionSource) -> Void

    /// Unwraps `store`, starting from `present` — the value it's known to hold now.
    public init<S: StoreType>(_ store: S, present: State) where S.Action == Action, S.State == State? {
        stateStream = store.stateStream.holdingLastPresent(fallback: present)
        _dispatch = { action, source in store.dispatch(action, source: source) }
    }

    /// Forwards the action to the underlying store unchanged.
    public func dispatch(_ action: Action, source: ActionSource) {
        _dispatch(action, source)
    }
}
