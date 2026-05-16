#if canImport(Observation) && canImport(SwiftUI)
// A single `import SwiftRexArchitecture` covers everything:
// @Prisms/@Lenses (FPMacros), @ViewModel/@BoundTo (SwiftRexSwiftUI),
// and @ObservationIgnored/ObservationRegistrar (Observation) used in @ViewModel expansions.
@_exported import FPMacros
@_exported import Observation
@_exported import SwiftRexSwiftUI

// MARK: - @Feature macro

/// Eliminates ``Feature`` protocol boilerplate from a feature enum.
///
/// Apply to an `enum` that serves as a feature namespace. The macro:
///
/// - Adds `Feature` protocol conformance via an extension
/// - Applies `@Prisms` to the nested `Action` enum (for ``TestStore`` `receive` assertions)
/// - Applies `@Lenses` to the nested `State` struct (for `liftState` ergonomics)
/// - Applies `@ViewModel` to the nested `ViewModel` class (no manual annotation needed)
///
/// ```swift
/// @Feature
/// enum MoviesFeature {
///     struct State: Sendable { ... }         // @Lenses applied automatically
///     enum Action: Sendable { ... }          // @Prisms applied automatically
///     struct Environment: Sendable { ... }
///
///     final class ViewModel { ... }          // @ViewModel applied automatically
///
///     static let mapState = ...
///     static let mapAction = ...
///     static func initialState() -> State { .init() }
///     static func behavior() -> Behavior<Action, State, Environment> { ... }
///
///     typealias Content = MovieListView      // still required — links feature to its view
/// }
/// ```
///
/// Because `@Feature` re-exports `FPMacros`, importing `SwiftRexArchitecture` is sufficient —
/// no explicit `import FPMacros` is needed in the file where `@Feature` is used.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(memberAttribute)
@attached(extension, conformances: Feature)
public macro Feature() = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
