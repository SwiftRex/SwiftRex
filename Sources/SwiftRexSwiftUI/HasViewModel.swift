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

    /// Initialiser called by ``FeatureHost/build(store:)`` to wire the view to its store.
    init(viewModel: VM)
}
#endif
