#if canImport(Observation)
import SwiftUI

/// A SwiftUI view driven by a ``ViewModel``-conforming class.
///
/// Conforming views receive a concrete `@ViewModel`-annotated class and gain true
/// field-level `@Observable` invalidation — only views that read a changed field re-render.
///
/// ## Conformance
///
/// ```swift
/// struct HeroDetailsView: View, HasViewModel {
///     typealias VM = HeroDetailsFeature.ViewModel   // nested @ViewModel class
///
///     let viewModel: HeroDetailsFeature.ViewModel   // plain let — see Lifecycle below
///
///     var body: some View {
///         Form {
///             Text(viewModel.name)                 // tracks \.name only
///             Text(viewModel.powers)               // tracks \.powers only
///             Button("Save") { viewModel.dispatch(.save(viewModel.powers)) }
///             Button("Close") { viewModel.dispatch(.close) }
///         }
///     }
/// }
/// ```
///
/// ## Lifecycle
///
/// `VM` is a reference-typed `@Observable` class. A plain `let` is sufficient for SwiftUI
/// to track it — `@Observable`'s registrar handles invalidation through the reference
/// regardless of `let` vs `var`. Use `@State var` only when the view itself creates and
/// owns the instance (e.g. at the root of a navigation stack). When ``FeatureHost`` creates
/// the view model and passes it in via ``init(viewModel:)``, `let` is always correct.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public protocol HasViewModel {
    /// The concrete `@ViewModel`-annotated class driving this view.
    associatedtype VM: ViewModel

    /// The view model instance. Declare as `let` in concrete implementations.
    var viewModel: VM { get }

    /// Initialiser called by ``FeatureHost/view(for:)`` to wire the view to its store.
    init(viewModel: VM)
}

// MARK: - @BoundTo macro

/// Eliminates ``HasViewModel`` boilerplate from a SwiftUI view struct.
///
/// Apply to a `struct` that conforms to `View` and pass the ``Feature`` type whose
/// ``Feature/ViewModel`` this view is driven by. The macro generates:
///
/// - `typealias VM = FeatureType.ViewModel`
/// - `let viewModel: FeatureType.ViewModel`
/// - `init(viewModel: FeatureType.ViewModel) { self.viewModel = viewModel }`
/// - `extension MyView: HasViewModel {}`
///
/// ```swift
/// @BoundTo(MoviesFeature.self)
/// struct MovieListView: View {
///     var body: some View {
///         List(viewModel.rows) { row in   // viewModel is generated
///             Text(row.title)
///         }
///         .onAppear { viewModel.dispatch(.onAppear) }
///     }
/// }
/// ```
///
/// If the view needs additional `@State` or requires a custom `init` that seeds
/// `@State` from `viewModel` data, write the `init` manually — the generated one
/// will be suppressed by the explicit declaration.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(member, names: named(VM), named(viewModel), named(init))
@attached(extension, conformances: HasViewModel)
public macro BoundTo<F>(_ feature: F.Type) = #externalMacro(module: "SwiftRexMacros", type: "BoundToMacro")
#endif
