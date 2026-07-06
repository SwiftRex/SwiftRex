// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    /// Binds a SwiftUI view to a `@Feature`'s view store by injecting a `viewStore` stored property with
    /// the observation wrapper that matches the feature's ``ViewStrategy``.
    ///
    /// Pass the feature type and the **same** `strategy:` you gave `@Feature` — a macro can't read another
    /// type's attributes, so the strategy is repeated here; the compiler enforces they agree (the
    /// feature's generated `view()` builds a store of exactly the injected type).
    ///
    /// ```swift
    /// @BoundTo(Movies.self, strategy: .observationGranular)
    /// struct MoviesView: View {
    ///     // injected: `let viewStore: TrackedViewStore<Movies.ViewState, Movies.ViewAction>`
    ///     var body: some View {
    ///         Text(viewStore.state.title)                 // field-level here
    ///         Button("tap") { viewStore.dispatch(.tapped) }
    ///     }
    /// }
    /// ```
    ///
    /// The `.combineObservable` strategy injects `@ObservedObject var viewStore: ObservableObjectStore<…>`
    /// instead — same body, coarse updates, iOS 13+. The body never changes across strategies.
    @attached(member, names: arbitrary)
    public macro BoundTo<F>(_ feature: F.Type, strategy: ViewStrategy) = #externalMacro(module: "SwiftRexMacros", type: "BoundToMacro")
#endif
