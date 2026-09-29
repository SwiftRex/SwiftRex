// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    /// Binds a SwiftUI view to a `@Feature`'s view store by injecting a `viewStore` stored property held
    /// the way the feature's ``ViewStrategy`` needs.
    ///
    /// Pass the feature type and the **same** `strategy:` you gave `@Feature` (both default to
    /// ``ViewStrategy/observation``) — a macro can't read another type's attributes, so the strategy is
    /// repeated here; the compiler enforces they agree (the feature's generated `view()` hands over a store
    /// of exactly the injected type).
    ///
    /// ```swift
    /// @BoundTo(Movies.self)
    /// struct MoviesView: View {
    ///     // injected: `let viewStore: ObservableStore<Movies.ViewAction, Movies.ViewState>`
    ///     var body: some View {
    ///         Text(viewStore.title)                     // depends on \.title only
    ///         Button("tap") { viewStore.dispatch(.tapped) }
    ///     }
    /// }
    /// ```
    ///
    /// `.combine` injects `@ObservedObject var viewStore: ObservableStore<…>` instead — same body, iOS 13+.
    @attached(member, names: arbitrary)
    public macro BoundTo<F>(_ feature: F.Type, strategy: ViewStrategy = .observation) =
        #externalMacro(module: "SwiftRexMacros", type: "BoundToMacro")
#endif
