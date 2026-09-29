// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// A key-path slice of an ``ObservableStore`` with its own action lane — observe, **then** project, and
    /// stay observable. It shares the root's snapshot and dependency registry, so it adds no subscription
    /// and no per-change work; reads through it are as granular as reads through the root.
    ///
    /// Build one from a node with ``StateNode/scoped(action:)``:
    ///
    /// ```swift
    /// PlayerControls(store: store.player.scoped(action: .action(\.player)))
    /// // inside: store.isPlaying, store.binding(.state(\.volume), dispatch: .action(\.setVolume)), …
    /// ```
    ///
    /// A projection through a **closure** (`store.projection(action:state:)`) can't stay granular — the
    /// registry can't see into an arbitrary function — so it returns a plain, non-observable
    /// `StoreProjection`; observe it again with ``SwiftRex/StoreType/observable(_:)``.
    @MainActor @dynamicMemberLookup
    public struct ScopedStore<RootAction: Sendable, RootState: Sendable, Action: Sendable, State: Sendable>:
    ObservableStoreType, DynamicProperty {
        @ObservedObject public private(set) var root: ObservableStore<RootAction, RootState>
        public let prefix: KeyPath<RootState, State>
        public let embed: @Sendable (Action) -> RootAction

        init(root: ObservableStore<RootAction, RootState>, prefix: KeyPath<RootState, State>, embed: @escaping @Sendable (Action) -> RootAction) {
            _root = ObservedObject(wrappedValue: root)
            self.prefix = prefix
            self.embed = embed
        }

        /// The whole slice — a coarse read (see ``ObservableStore/state``).
        public var state: State { root.read(prefix) }

        /// The slice, recording nothing — what a store built on this one reads to follow it.
        public var untrackedState: State { root.peek(prefix) }

        public func dispatch(_ action: Action, source: ActionSource) {
            root.dispatch(embed(action), source: source)
        }

        /// Forwards to the root's gated ``ObservableStore/observe(willChange:didChange:)``.
        public func observe(
            willChange: @escaping @MainActor @Sendable () -> Void,
            didChange: @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken {
            root.observe(willChange: willChange, didChange: didChange)
        }
    }
#endif
