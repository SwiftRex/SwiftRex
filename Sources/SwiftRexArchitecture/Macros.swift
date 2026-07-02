#if canImport(Observation) && canImport(SwiftUI)
// A single `import SwiftRexArchitecture` covers everything:
// SwiftRex core (StoreType/Behavior/Reducer), @Prisms/@Lenses (FPMacros),
// @ViewModel/@BoundTo (SwiftRexSwiftUI), Reader (DataStructure), and Observation.
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
/// - Applies `@Prisms` to the nested `Action`, `@Lenses` to the nested `State`, and `@ViewModel`
///   to the nested `ViewModel` class.
/// - Synthesises `static func initialState(with _: Void) -> State { .init() }` when you don't
///   write one (skipped if you declare a custom `Input` seed).
/// - Generates `static func view(store:environment:) -> some View`, which builds the `@ViewModel`
///   from an environment-applied projection and hands it to the `Content` view. The concrete
///   `ViewModel`/`Content` types stay hidden behind the opaque `some View` return.
///
/// It generates **no** protocol conformance. Declare `State`/`Action`/`Environment`/`Input`
/// `public` on an entry point (they must be liftable); keep `ViewState`/`ViewAction`/`ViewModel`/
/// `Content` `internal` so they never cross the module boundary.
///
/// ```swift
/// @Feature(.publicEntryPoint)
/// public enum Movies {
///     public struct State: Sendable { ... }          // @Lenses applied automatically
///     public enum Action: Sendable { ... }           // @Prisms applied automatically
///     public struct Environment: Sendable { ... }
///
///     final class ViewModel { ... }                  // @ViewModel applied automatically; internal
///     static let mapState  = ...                      // Reader<Environment, (State) -> ViewState>
///     static let mapAction = ...
///     static func behavior() -> Behavior<Action, State, Environment> { ... }
///     typealias Content = MoviesView                  // the internal SwiftUI view
///     // `initialState(with:)` and `view(store:environment:)` are generated.
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(member, names: named(initialState), named(view))
@attached(memberAttribute)
public macro Feature(_ role: FeatureRole) = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
