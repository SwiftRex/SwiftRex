// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI) && canImport(Combine)
    import SwiftRex
    import SwiftUI

    /// The store a view **receives** — hold it as a plain `let`, whatever the ``ViewStrategy``.
    ///
    /// A `ViewStore` is a reference to an ``ObservableStore`` someone else owns (``ObservedStore``,
    /// ``ObservableStoreHost``, or `@Feature`'s generated view). Re-initialising the receiving view hands it
    /// the same store back, so the snapshot and the recorded dependencies survive parent re-renders. It is a
    /// `DynamicProperty` that also carries the store's Combine subscription, so the same `let` works whether
    /// the store signals through Observation or Combine — a receiver never picks a property wrapper.
    ///
    /// ```swift
    /// struct Root: View {
    ///     @ObservedStore var store = appStore        // the owner: built once
    ///     var body: some View { Counter(store: store) }
    /// }
    /// struct Counter: View {
    ///     let store: ViewStore<AppAction, AppState>  // a receiver
    ///     var body: some View { Text("\(store.count)") }   // depends on \.count only
    /// }
    /// ```
    ///
    /// Reads are granular exactly as on ``ObservableStore`` — leaves, ``StateNode``s, `each`, `scoped` — and
    /// the binding and presentation helpers work straight off it.
    @MainActor @dynamicMemberLookup
    public struct ViewStore<Action: Sendable, State: Sendable>: ObservableStoreType, DynamicProperty {
        @ObservedObject public private(set) var root: ObservableStore<Action, State>

        /// A receiver of `store`. Build the store once, elsewhere — see ``ObservableStore`` → Ownership.
        public init(_ store: ObservableStore<Action, State>) {
            _root = ObservedObject(wrappedValue: store)
        }

        public var prefix: KeyPath<State, State> { root.prefix }
        public var embed: @Sendable (Action) -> Action { root.embed }

        /// The whole state — a coarse read (see ``ObservableStore/state``).
        public var state: State { root.state }

        /// The state, recording nothing — what a store built on this one reads to follow it.
        public var untrackedState: State { root.untrackedState }

        public func read<T>(_ keyPath: KeyPath<State, T>) -> T {
            root.read(keyPath)
        }

        public func peek<T>(_ keyPath: KeyPath<State, T>) -> T {
            root.peek(keyPath)
        }

        public func dispatch(_ action: Action, source: ActionSource) {
            root.dispatch(action, source: source)
        }

        public func observe(
            willChange: @escaping @MainActor @Sendable () -> Void,
            didChange: @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken {
            root.observe(willChange: willChange, didChange: didChange)
        }
    }

    /// The store a view **owns** — observes any ``StoreType`` once per view identity and hands the view a
    /// ``ViewStore``.
    ///
    /// The initial value is an autoclosure, evaluated only the first time the view appears (like
    /// `@StateObject`), so re-initialising the view never rebuilds or re-subscribes the store:
    ///
    /// ```swift
    /// struct Root: View {
    ///     @ObservedStore var store = appStore                    // Observation on iOS 17+, Combine below
    ///     @ObservedStore(.combine) var legacy = otherStore       // force Combine signalling
    ///     var body: some View { Child(store: store) }            // children receive `let ViewStore`
    /// }
    /// ```
    ///
    /// Works in any view (and in an `App`). To observe a projection, pass it: `@ObservedStore var screen =
    /// appStore.buffer().projection(action: …, state: …)`.
    @MainActor @propertyWrapper
    public struct ObservedStore<Action: Sendable, State: Sendable>: DynamicProperty {
        @StateObject private var store: ObservableStore<Action, State>

        public init<Upstream: StoreType>(
            wrappedValue upstream: @autoclosure @escaping () -> Upstream,
            _ strategy: ViewStrategy = .automatic
        ) where Upstream.Action == Action, Upstream.State == State {
            _store = StateObject(wrappedValue: ObservableStore(upstream(), strategy: strategy))
        }

        public var wrappedValue: ViewStore<Action, State> { ViewStore(store) }
    }
#endif
