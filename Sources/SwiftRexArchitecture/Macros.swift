// SPDX-License-Identifier: Apache-2.0

#if canImport(Observation) && canImport(SwiftUI)
    // A single `import SwiftRexArchitecture` covers everything:
    // SwiftRex core (StoreType/Behavior/Reducer), @Prisms/@Lenses/@ApplyOptics (FPMacros),
    // ViewStore/GranularTracking/@OwnedStore/@BoundTo (SwiftRexSwiftUI), Reader (DataStructure), and Observation.
    @_exported import DataStructure
    @_exported import FPMacros
    @_exported import Observation
    @_exported import SwiftRex
    @_exported import SwiftRexSwiftUI

    // MARK: - @Feature macro

    /// Turns a feature `enum` into a full feature (behavior + view) or a logic-only one (behavior).
    ///
    /// Apply to an `enum` namespace, optionally with a `ViewStrategy` (`strategy:`, default `.automatic` —
    /// Observation on iOS 17+, Combine below; `.combine` forces Combine). The macro:
    /// - Applies `@ApplyOptics(recursively: true)` to every nested domain type — `@Lenses` on structs
    ///   (`State`, …), `@Prisms` on enums (`Action`, `ViewAction`, …). `ViewState` gets no optics.
    /// - Synthesises `static func initialState(with _: Void) -> State { .init() }` when you don't
    ///   write one (skipped if you declare a custom `Input` seed).
    /// - Generates `static func view(store:environment:) -> some View` (when a `Content` view exists),
    ///   which makes a `ViewStore` once per view identity (kept by the generated `FeatureRoot` view) from an
    ///   environment-aware projection — buffered before the map when `State` is `Equatable` — and hands it
    ///   to `Content` as a `ViewStore`. Nothing is availability-gated — the store picks its signal at
    ///   runtime. `ViewState`/`ViewAction`/`Content` stay behind `some View`.
    ///
    /// The **view projection layer is optional**: omit `ViewState`/`ViewAction`/`mapState`/`mapAction`
    /// and the macro aliases `ViewState = State`, `ViewAction = Action`, and `view()` wraps the store
    /// directly (no projection). The view then reads the domain `State`/`Action`. Declare a `ViewState`
    /// struct only when the UI needs a different shape (e.g. an `Int` shown as a `String`) — reads are
    /// granular per key path either way, so a `ViewState` is never needed just for performance. **`Environment`
    /// is optional too** — omit it and the macro aliases it to `Void`. So the leanest feature is just
    /// `State`/`Action`/`behavior()`/`Content`.
    ///
    /// **Access follows the `enum`'s own access** — a `public enum` gets `public` members (a module
    /// entry point, whose `State`/`Action`/`Environment`/`Input` you also declare `public` so they can
    /// be lifted); a plain `enum` keeps its members `internal` (a screen composed inside a module). No
    /// `type:` argument — the declaration says it, exactly like `@BoundTo`.
    ///
    /// **The `Feature` conformance is generated:** a feature that has a view (a `Content`, or a
    /// hand-written `view(store:environment:)`) conforms to ``Feature``; a view-less feature is a
    /// behavior only and gets no `Feature` conformance (never availability-gated). You no longer write
    /// `extension X: Feature {}` by hand.
    ///
    /// ```swift
    /// @Feature
    /// public enum Movies {                               // `public` ⇒ public members + `Feature`
    ///     public struct State: Sendable { ... }          // @Lenses applied automatically
    ///     public enum Action: Sendable { ... }           // @Prisms applied automatically
    ///     public struct Environment: Sendable { ... }
    ///
    ///     struct ViewState: Sendable, Equatable { ... }   // optional — only when the UI needs another shape
    ///     enum ViewAction: Sendable { ... }               // @Prisms applied automatically
    ///     static let mapState  = ...                      // Reader<Environment, (State) -> ViewState>
    ///     static let mapAction = ...                      // Reader<Environment, (ViewAction) -> Action>
    ///     static func behavior() -> Behavior<Action, State, Environment> { ... }
    ///     typealias Content = MoviesView                  // internal view; @BoundTo(Movies.self) injects its viewStore
    ///     // `initialState(with:)`, `view(store:environment:)`, and `: Feature` are generated.
    /// }
    /// ```
    @attached(member, names: named(initialState), named(view), named(FeatureRoot), named(ViewState), named(ViewAction), named(Environment))
    @attached(memberAttribute)
    @attached(extension, conformances: Feature)
    public macro Feature(strategy: ViewStrategy = .automatic) = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
