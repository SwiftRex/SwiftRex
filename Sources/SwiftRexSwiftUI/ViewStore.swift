// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation)
    import Observation
    import SwiftRex

    /// A generic, `@Observable` view store — one class over any ``StoreType``, holding the whole
    /// projected `ViewState` in a single observed property and forwarding dispatch.
    ///
    /// It is the coarse alternative to ``TrackedViewStore``: instead of a `@Tracked` field-by-field
    /// mirror (field-level invalidation), `ViewStore` observes `ViewState` as a whole. That means the
    /// observing `body` re-evaluates on any `ViewState` change — but SwiftUI's own structural diffing
    /// skips redrawing subviews whose inputs didn't change, so the difference from field-level tracking
    /// is *body re-evaluation* only, which is cheap. Reach for `@Tracked` / ``TrackedViewStore`` when you
    /// have a genuinely hot, wide screen and measured a win; otherwise `ViewStore` keeps it simple.
    ///
    /// Build one from an environment-aware projection so the view formats/parses with live dependencies:
    ///
    /// ```swift
    /// let store = ViewStore(appStore.projection(environment: world, action: mapAction, state: mapState))
    /// // in the view: store.state.label, store.dispatch(.tapped)
    /// ```
    @available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
    @MainActor
    @Observable
    public final class ViewStore<ViewState: Sendable, ViewAction: Sendable>: StoreType {
        /// The current projected view state. Re-read from the underlying store on every mutation and
        /// tracked by `@Observable`, so SwiftUI re-evaluates the observing `body` when it changes.
        public private(set) var state: ViewState

        @ObservationIgnored private let _dispatch: @MainActor @Sendable (ViewAction, ActionSource) -> Void
        @ObservationIgnored private let _observe: @MainActor @Sendable (
            @escaping @MainActor @Sendable () -> Void,
            @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken
        @ObservationIgnored private var _token: SubscriptionToken?

        /// Seeds `state` from the store and subscribes to it. The subscription is retained for the
        /// `ViewStore`'s lifetime (RAII) — dropping the `ViewStore` cancels it.
        public init(_ store: some StoreType<ViewAction, ViewState>) {
            state = store.state
            _dispatch = { action, source in store.dispatch(action, source: source) }
            _observe = { willChange, didChange in store.observe(willChange: willChange, didChange: didChange) }
            _token = store.observe(didChange: { [weak self] in self?.state = store.state })
        }

        // MARK: - StoreType

        //
        // Conforming makes every store-backed helper (bindings, navigation, re-projection) available on
        // the view store. `dispatch(_:source:)` and `observe` forward to the underlying store; the
        // `dispatch(_:file:function:line:)` / `observe(didChange:)` conveniences come from StoreType.

        public func dispatch(_ action: ViewAction, source: ActionSource) {
            _dispatch(action, source)
        }

        public func observe(
            willChange: @escaping @MainActor @Sendable () -> Void,
            didChange: @escaping @MainActor @Sendable () -> Void
        ) -> SubscriptionToken {
            _observe(willChange, didChange)
        }
    }
#endif
