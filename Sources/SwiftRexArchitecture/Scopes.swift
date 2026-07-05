#if canImport(Observation) && canImport(SwiftUI)
import SwiftRex

/// A single registration point for an app's scoped feature behaviors.
///
/// List every feature's ``Scope`` once; ``behavior`` folds their `lifted` behaviors into one. This
/// is the app-composition companion to ``Scope`` — declaring a scope registers its behavior, so you
/// can't wire a feature into state/action without also composing its behavior:
///
/// ```swift
/// let features = Scopes(homeScope, detailScope, settingsScope)
/// let appBehavior = Behavior.combine([features.behavior, navigationReducer, loggingBehavior])
/// let store = Store(initial: .init(), behavior: appBehavior, environment: world)
/// ```
///
/// The same scope values feed a hand-written router's `@ViewBuilder view(for:)` switch, so behavior
/// registration and navigation share one source of truth. (A future collecting macro could derive
/// this list from the route enum; today it is one explicit array — the single place to add a
/// feature.)
public struct Scopes<GlobalAction: Sendable, GlobalState: Sendable, GlobalEnvironment: Sendable>: Sendable {
    private let scopes: [Scope<GlobalAction, GlobalState, GlobalEnvironment>]

    /// Registers a list of feature scopes.
    public init(_ scopes: Scope<GlobalAction, GlobalState, GlobalEnvironment>...) {
        self.scopes = scopes
    }

    /// Registers a list of feature scopes (array form).
    public init(_ scopes: [Scope<GlobalAction, GlobalState, GlobalEnvironment>]) {
        self.scopes = scopes
    }

    /// The combined behavior of every registered scope — fold this into the app behavior.
    public var behavior: Behavior<GlobalAction, GlobalState, GlobalEnvironment> {
        .combine(scopes.map(\.lifted))
    }
}
#endif
