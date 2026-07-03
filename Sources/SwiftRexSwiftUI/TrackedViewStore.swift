#if canImport(Observation)
import Observation
import SwiftRex

// MARK: - Protocols

/// An `@Observable` reference mirror of a value `ViewState`, updated in place so field-level
/// observation survives across store changes.
///
/// You never write a conformance by hand — `@Tracked` on a `ViewState` struct generates the
/// nested `Tracked` class that conforms to this.
///
/// `Sendable` (so a `TrackedViewStore` can expose it as its `StoreType.State`); the generated mirror
/// is `@unchecked Sendable` because it is only ever mutated on the main actor via `TrackedViewStore`.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol TrackedMirror: AnyObject, Sendable {
    /// The value type this mirror reflects (the `@Tracked` `ViewState`).
    associatedtype Source

    /// Seeds every field from a value snapshot.
    @MainActor init(_ source: Source)

    /// Copies each changed field from a fresh snapshot — touching only fields that differ, so
    /// `@Observable` fires per field rather than wholesale.
    @MainActor func update(from source: Source)
}

/// A value `ViewState` that carries an `@Observable` reference ``TrackedMirror`` for field-level
/// view invalidation. Synthesised by `@Tracked`.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol TrackedState: Sendable {
    /// The generated `@Observable` mirror — `Self.Tracked`.
    associatedtype Tracked: TrackedMirror where Tracked.Source == Self
}

// MARK: - TrackedViewStore

/// The field-level counterpart to ``ViewStore``: a plain (non-`@Observable`) class holding a
/// persistent, `@Observable` ``TrackedState/Tracked`` mirror that it updates in place.
///
/// The granularity comes entirely from the mirror: reading `store.state.title` in a `body` reaches
/// `Tracked.title` (an `@Observable` access), so SwiftUI invalidates only for the fields the view
/// actually reads. `TrackedViewStore` itself needs no `@Observable` — `state` is a `let` that never
/// reassigns; only its fields change.
///
/// ```swift
/// @Tracked struct ViewState { var title: String; var count: Int }
/// let store = TrackedViewStore(appStore.projection(environment: world, action: mapAction, state: mapState))
/// // in the view: store.state.title      // invalidates only when `title` changes
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public final class TrackedViewStore<ViewState: TrackedState, ViewAction: Sendable>: StoreType {
    /// The persistent, field-observed mirror. A `let` — updated in place, never reassigned. This is
    /// the store's `StoreType.State`, so `viewStore.state.field` reads a tracked field.
    public let state: ViewState.Tracked

    private let _dispatch: @MainActor @Sendable (ViewAction, ActionSource) -> Void
    private let _observe: @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void,
        @escaping @MainActor @Sendable () -> Void
    ) -> SubscriptionToken
    private var _token: SubscriptionToken?

    /// Seeds the mirror from the store and subscribes; on each change the mirror is updated in
    /// place (field-diffed). The subscription is retained for the store's lifetime (RAII).
    public init(_ store: some StoreType<ViewAction, ViewState>) {
        state = ViewState.Tracked(store.state)
        _dispatch = { action, source in store.dispatch(action, source: source) }
        _observe = { willChange, didChange in store.observe(willChange: willChange, didChange: didChange) }
        _token = store.observe(didChange: { [weak self] in self?.state.update(from: store.state) })
    }

    // MARK: - StoreType
    //
    // `StoreType.State` is the `@Observable` mirror, so store-backed helpers (bindings, navigation)
    // read/write tracked fields. `dispatch`/`observe` forward to the underlying store; the call-site
    // and `didChange` conveniences come from StoreType. Note: `.buffer()` needs `State: Equatable`,
    // so it does not apply to the (reference-type) mirror.

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

// MARK: - @Tracked macro

/// Generates an `@Observable` reference mirror for a value `ViewState`, giving field-level view
/// invalidation when paired with ``TrackedViewStore``.
///
/// Apply to a `struct` whose stored properties are the view's fields. The macro generates a nested
/// `Tracked` class (the `@Observable` mirror, with an `init(_:)` seed and an in-place
/// `update(from:)`) and a ``TrackedState`` conformance. `@Feature` builds a ``TrackedViewStore``
/// instead of a plain ``ViewStore`` when it sees this attribute on the `ViewState`.
///
/// ```swift
/// @Tracked struct ViewState { var title: String; var count: Int }
/// // generated: ViewState.Tracked (@Observable) + extension ViewState: TrackedState
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(member, names: named(Tracked))
@attached(extension, conformances: TrackedState)
public macro Tracked() = #externalMacro(module: "SwiftRexMacros", type: "TrackedMacro")
#endif
