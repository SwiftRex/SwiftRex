// SPDX-License-Identifier: Apache-2.0

#if canImport(SwiftUI)
    /// A view that navigates — it holds a **router** it was handed at construction and asks it to build
    /// destination views on demand.
    ///
    /// This is the opt-in seam for navigation. A view that presents/pushes other features conforms to
    /// `Routable`, stores its router as a `let`, and calls it from destination closures:
    ///
    /// ```swift
    /// struct HomeView: View, Routable {
    ///     let viewStore: ViewStore<Home.State, Home.Action>
    ///     let router: AppRouter                        // handed in at construction, traps store + world
    ///
    ///     var body: some View {
    ///         List { … }
    ///             .sheet(isPresented: viewStore.presence(.state(\.route), dismiss: .dismiss)) {
    ///                 router.view(for: .detail)        // env-free body; the router supplies env
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// ## Why hold the router, not read it ambiently
    ///
    /// A router injected at construction is deterministic across sheet/modal boundaries — the exact
    /// place SwiftUI's `@Environment` propagation is unreliable. Because the router builds every view,
    /// it re-hands itself at each construction, so nested flows (a sheet that itself navigates) always
    /// have their router. See ``Router`` for the destination-building side.
    ///
    /// A view conforms manually today; a future `routing:` argument on the feature macros can synthesize
    /// the `router` property and this conformance.
    public protocol Routable {
        /// The router type this view navigates through — a concrete app router, or a narrow per-feature
        /// routing protocol it conforms to (so the view sees only the destinations it needs).
        associatedtype Routing

        /// The router, trapped at construction. Building a destination (`router.view(for:)`) supplies
        /// the child's store projection and environment — the view body never touches `Environment`.
        var router: Routing { get }
    }
#endif
