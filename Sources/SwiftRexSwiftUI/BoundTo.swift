// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    /// Binds a SwiftUI view to a `@Feature`'s view store by injecting
    /// `let viewStore: ViewStore<F.ViewAction, F.ViewState>`.
    ///
    /// A ``ViewStore`` is a plain-`let` receiver under every ``ViewStrategy`` — the strategy is chosen once,
    /// on `@Feature` — so there is nothing to repeat here. The feature's generated `view(store:environment:)` returns a
    /// `FeatureRoot` that keeps the view store (made once per view identity) and hands it over through the memberwise
    /// `init(viewStore:)`.
    ///
    /// ```swift
    /// @BoundTo(Movies.self)
    /// struct MoviesView: View {
    ///     // injected: `let viewStore: ViewStore<Movies.ViewAction, Movies.ViewState>`
    ///     var body: some View {
    ///         Text(viewStore.state.title) // depends on \.title only
    ///         Button("tap") { viewStore.dispatch(.tapped) }
    ///     }
    /// }
    /// ```
    @attached(member, names: arbitrary)
    public macro BoundTo<F>(_ feature: F.Type) = #externalMacro(module: "SwiftRexMacros", type: "BoundToMacro")
#endif
