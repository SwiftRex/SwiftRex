// SPDX-License-Identifier: Apache-2.0

// MARK: - transpose — Store<T?> into a stream of Store<T>?
//
// A store of an optional (`StoreProjection<A, T?>`, an element by id, a dictionary value) is not what a child
// wants: it wants a store of the *unwrapped* value, and no store at all while the value is absent. A plain store
// can't be read, so it can't answer "is it there?" once and for all — the answer changes over time. `transpose`
// keeps it in time: a stream that emits a child store when the value appears and `nil` when it goes away.
//
//   store.projection(…)      StoreProjection<A, T?>
//       .transpose()         StateStream<StoreProjection<A, T>?>   — emits on the presence edge only
//
// A SwiftUI `ViewStore` offers the same swap read synchronously in a body (`viewStore.transpose()`); this is the
// form for everything else — UIKit, AppKit, a renderer on Linux, Windows or Android, a service.

extension StoreType {
    /// Swaps a store of an optional into a stream of optional stores: the current presence when observed, then
    /// a new value **only when presence flips** — a child store when the value appears, `nil` when it goes away.
    ///
    /// ```swift
    /// token = store.projection(action: AppAction.editor, state: \.editor).transpose().observe { editor in
    ///     editor.map(presentEditor) ?? dismissEditor()          // UIKit: present / dismiss on the edge
    /// }
    /// ```
    ///
    /// Each child store follows its own state (the parent's stream is not re-emitted while the value stays
    /// present), dispatches through this store, and **holds its last present value** once the value is gone —
    /// so a screen that is still animating away keeps showing what it showed.
    ///
    /// **The mechanics, and the pitfalls.** A child store is a *follower*, valid while its value is present:
    /// - Act on the stream, not on a store you kept. Present on `.some`, tear down on `nil`; a child store you
    ///   hold on to after `nil` keeps showing its last value and still dispatches — to a reducer that no longer
    ///   has the value, so its actions are usually ignored.
    /// - Presence is decided by the stream. Deciding once (`subscribe` and look at the current value) and
    ///   keeping the answer is a snapshot that nothing invalidates.
    /// - Every `.some` after a `nil` is a **new** child store: a value that disappears and comes back is a new
    ///   presentation.
    public func transpose<Wrapped: Sendable>() -> StateStream<StoreProjection<Action, Wrapped>?> where State == Wrapped? {
        let parent = self
        return stateStream
            .removeDuplicates { ($0 == nil) == ($1 == nil) }
            .mapIsolated { value in
                value.map { current in
                    StoreProjection(store: parent, action: { $0 }, stateStream: parent.stateStream.holdingLastPresent(fallback: current))
                }
            }
    }
}
