#if canImport(Observation) && canImport(SwiftUI)
// A single `import SwiftRexArchitecture` covers everything:
// SwiftRex core (StoreType/Behavior/Reducer), @Prisms/@Lenses (FPMacros),
// ViewStore/TrackedViewStore/@Tracked (SwiftRexSwiftUI), Reader (DataStructure), and Observation.
@_exported import DataStructure
@_exported import FPMacros
@_exported import Observation
@_exported import SwiftRex
@_exported import SwiftRexSwiftUI

// MARK: - @Feature macro

/// Turns a feature `enum` into a module entry point or an internal screen — the single macro for
/// both, distinguished only by its ``FeatureRole``.
///
/// Apply to an `enum` namespace with a ``FeatureRole`` (`type:`) and a ``ViewStrategy``
/// (`strategy:`). The macro:
/// - Applies `@Prisms` to the nested `Action` and `ViewAction`, and `@Lenses` to the nested `State`.
///   For `strategy: .observationGranular` it also attaches `@Tracked` to the nested `ViewState`.
/// - Synthesises `static func initialState(with _: Void) -> State { .init() }` when you don't
///   write one (skipped if you declare a custom `Input` seed).
/// - Generates `static func view(store:environment:) -> some View` (when a `Content` view exists),
///   which builds the view store from an environment-aware projection and hands it to `Content`.
///   The store type follows `strategy:` — `ViewStore`, `TrackedViewStore`, or `ObservableObjectStore`
///   — and the generated `view()` is `@available(iOS 17)` for the two Observation strategies, ungated
///   (iOS 13+) for `.combineObservable`. `ViewState`/`ViewAction`/`Content` stay behind `some View`.
///
/// The macro itself is **not** availability-gated, so `.combineObservable` features can target iOS 16.
/// It generates **no** protocol conformance. Declare `State`/`Action`/`Environment`/`Input` `public`
/// on a `.moduleEntryPoint` (they must be liftable); keep the view layer `internal`.
///
/// ```swift
/// @Feature(type: .moduleEntryPoint, strategy: .observationSimple)
/// public enum Movies {
///     public struct State: Sendable { ... }          // @Lenses applied automatically
///     public enum Action: Sendable { ... }           // @Prisms applied automatically
///     public struct Environment: Sendable { ... }
///
///     struct ViewState: Sendable, Equatable { ... }   // .observationGranular adds @Tracked for you
///     enum ViewAction: Sendable { ... }               // @Prisms applied automatically
///     static let mapState  = ...                      // Reader<Environment, (State) -> ViewState>
///     static let mapAction = ...                      // Reader<Environment, (ViewAction) -> Action>
///     static func behavior() -> Behavior<Action, State, Environment> { ... }
///     typealias Content = MoviesView                  // internal view; use @BoundTo(Movies.self, strategy:)
///     // `initialState(with:)` and `view(store:environment:)` are generated.
/// }
/// ```
@attached(member, names: named(initialState), named(view))
@attached(memberAttribute)
public macro Feature(type: FeatureRole, strategy: ViewStrategy) = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
