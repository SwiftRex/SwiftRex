// SPDX-License-Identifier: Apache-2.0

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

    /// Turns a feature `enum` into a full feature (behavior + view) or a logic-only one (behavior).
    ///
    /// Apply to an `enum` namespace with a ``ViewStrategy`` (`strategy:`). The macro:
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
    /// The **view projection layer is optional**: omit `ViewState`/`ViewAction`/`mapState`/`mapAction`
    /// and the macro aliases `ViewState = State`, `ViewAction = Action`, and `view()` wraps the store
    /// directly (no projection). The view then reads the domain `State`/`Action`. Declare a `ViewState`
    /// struct only when the UI needs a different shape (e.g. an `Int` shown as a `String`); under
    /// `.observationGranular`, a missing `ViewState` puts `@Tracked` on `State` itself. **`Environment`
    /// is optional too** — omit it and the macro aliases it to `Void`. So the leanest feature is just
    /// `State`/`Action`/`behavior()`/`Content`.
    ///
    /// **Access follows the `enum`'s own access** — a `public enum` gets `public` members (a module
    /// entry point, whose `State`/`Action`/`Environment`/`Input` you also declare `public` so they can
    /// be lifted); a plain `enum` keeps its members `internal` (a screen composed inside a module). No
    /// `type:` argument — the declaration says it, exactly like `@BoundTo`/`@Tracked`.
    ///
    /// **The `Feature` conformance is generated:** a feature that has a view (a `Content`, or a
    /// hand-written `view(store:environment:)`) conforms to ``Feature``; a view-less feature is a
    /// behavior only and gets no `Feature` conformance. The `Feature` conformance is `@available(iOS 17)`
    /// for the two Observation strategies, ungated for `.combineObservable`. You no longer write
    /// `extension X: Feature {}` by hand.
    ///
    /// ```swift
    /// @Feature(strategy: .observationSimple)
    /// public enum Movies {                               // `public` ⇒ public members + `Feature`
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
    ///     // `initialState(with:)`, `view(store:environment:)`, and `: Feature` are generated.
    /// }
    /// ```
    @attached(member, names: named(initialState), named(view), named(ViewState), named(ViewAction), named(Environment))
    @attached(memberAttribute)
    @attached(extension, conformances: Feature)
    public macro Feature(strategy: ViewStrategy) = #externalMacro(module: "SwiftRexMacros", type: "FeatureMacro")
#endif
