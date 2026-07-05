#if canImport(Observation) && canImport(SwiftUI)
import SwiftRex
import SwiftUI

/// A feature: it produces a ``Behavior`` and builds its SwiftUI view. One protocol so a ``Scope`` can
/// abstract over a feature — driving **both** its behavior and its view — without naming it.
///
/// It exposes only the liftable/viewable surface (`Action`/`State`/`Environment` + `behavior`/`view`),
/// never `ViewState`/`ViewAction` — the reason the earlier view-model-exposing protocol was retired.
///
/// `view` takes `any StoreType<Action, State>` (a concrete existential) rather than a generic
/// `some StoreType`, so its `some View` result can bind ``Body``; a generic method could not. A
/// `Store` or a `StoreProjection` boxes into the existential, so callers are unaffected.
///
/// Conformance is one line — `extension MyFeature: Feature {}` — where Swift infers the associated
/// types from the members `@Feature` already generates. (The macro can't add it automatically: an
/// extension macro can't infer `Body` from a member-macro-generated `some View` method.)
public protocol Feature {
    /// The feature's action type.
    associatedtype Action: Sendable
    /// The feature's state type.
    associatedtype State: Sendable
    /// The feature's environment (dependencies) type.
    associatedtype Environment: Sendable
    /// The concrete view type produced — inferred from `view`'s `some View` result.
    associatedtype Body: View

    /// The feature's behavior — its reducer/effects/supervisor, composed once.
    static func behavior() -> Behavior<Action, State, Environment>

    /// Builds the feature's view from the (already scoped) store and environment — the caller
    /// supplies both, resolving the navigation crux (an environment-free view body never builds this).
    @MainActor static func view(store: any StoreType<Action, State>, environment: Environment) -> Body
}
#endif
