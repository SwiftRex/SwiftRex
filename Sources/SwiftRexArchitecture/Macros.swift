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
/// Apply to an `enum` namespace. The macro:
/// - Applies `@Prisms` to the nested `Action` and `ViewAction`, and `@Lenses` to the nested `State`.
/// - Synthesises `static func initialState(with _: Void) -> State { .init() }` when you don't
///   write one (skipped if you declare a custom `Input` seed).
/// - Generates `static func view(store:environment:) -> some View` (when a `Content` view exists),
///   which builds the view store from an environment-aware projection and hands it to `Content`.
///   The store is a coarse ``ViewStore`` — or a field-level ``TrackedViewStore`` when the nested
///   `ViewState` is `@Tracked`. `ViewState`/`ViewAction`/`Content` stay hidden behind `some View`.
///
/// It generates **no** protocol conformance. Declare `State`/`Action`/`Environment`/`Input`
/// `public` on an entry point (they must be liftable); keep `ViewState`/`ViewAction`/`Content`
/// `internal` so they never cross the module boundary.
///
/// ```swift
/// @Feature(.publicEntryPoint)
/// public enum Movies {
///     public struct State: Sendable { ... }          // @Lenses applied automatically
///     public enum Action: Sendable { ... }           // @Prisms applied automatically
///     public struct Environment: Sendable { ... }
///
///     struct ViewState: Sendable, Equatable { ... }   // add @Tracked for field-level observation
///     enum ViewAction: Sendable { ... }               // @Prisms applied automatically
///     static let mapState  = ...                      // Reader<Environment, (State) -> ViewState>
///     static let mapAction = ...                      // Reader<Environment, (ViewAction) -> Action>
///     static func behavior() -> Behavior<Action, State, Environment> { ... }
///     typealias Content = MoviesView                  // the internal SwiftUI view (holds `viewStore`)
///     // `initialState(with:)` and `view(store:environment:)` are generated.
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(member, names: named(initialState), named(view))
@attached(memberAttribute)
public macro Feature(_ role: FeatureRole) = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
