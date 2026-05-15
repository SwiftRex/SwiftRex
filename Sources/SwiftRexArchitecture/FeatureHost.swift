#if canImport(Observation)
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI

/// A type-erased handle for a ``Feature`` that exposes only its domain-level surface.
///
/// `FeatureHost` holds ``behavior`` for lifting into a parent store, and ``view(for:)``
/// for producing a `some View` without leaking any view-layer generics.
/// After `init`, `F.ViewModel`, `F.Content`, `F.ViewState`, and `F.ViewAction` are gone.
///
/// For a complete example including `Feature`, domain types, and app-level wrappers, see the
/// [SwiftRex Architecture section in the README](https://github.com/SwiftRex/SwiftRex#swiftrex-architecture).
///
/// ## Usage
///
/// ```swift
/// // Declare a typed convenience alongside the Feature:
/// extension FeatureHost
/// where Action      == MoviesFeature.Action,
///       State       == MoviesFeature.State,
///       Environment == MoviesFeature.Environment {
///     static var movies: Self { .init(MoviesFeature.self) }
/// }
///
/// // Embed behavior in the parent store:
/// Store(
///     initial: AppState(),
///     behavior: FeatureHost.movies.behavior
///         .liftAction(AppAction.prism.movies)
///         .liftState(AppState.lens.movies)
///         .liftEnvironment { ... },
///     environment: AppEnvironment(...)
/// )
///
/// // Produce the view — all view-layer generics are erased:
/// FeatureHost.movies.view(for: appStore.projection(
///     action: AppAction.prism.movies.review,
///     state:  AppState.lens.movies.get
/// ))
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct FeatureHost<Action: Sendable, State: Sendable, Environment: Sendable>: Sendable {

    /// The feature's reducer + effects, ready to be lifted and embedded in a parent ``Store``.
    public let behavior: Behavior<Action, State, Environment>

    private let _makeView: @MainActor @Sendable (any StoreType<Action, State>) -> AnyView

    /// Creates a `FeatureHost` from a ``Feature`` type, erasing all view-layer generics.
    ///
    /// This is the only place in the codebase where the concrete `F.ViewModel`, `F.Content`,
    /// `F.mapState`, and `F.mapAction` are referenced. After this call they are gone.
    ///
    /// - Parameter feature: The `Feature` metatype — e.g. `HeroDetailsFeature.self`.
    public init<F: Feature>(_ feature: F.Type)
    where F.Action == Action, F.State == State, F.Environment == Environment {
        behavior = F.behavior()
        _makeView = { @MainActor store in
            let vm = F.ViewModel(store: store.projection(
                action: F.mapAction,
                state: F.mapState
            ))
            return AnyView(F.Content(viewModel: vm))
        }
    }

    /// Returns the feature's view for the given store projection.
    ///
    /// Pass a `StoreType` whose `Action` and `State` match this host's type parameters —
    /// typically a projection of a parent store scoped to the feature's slice:
    ///
    /// ```swift
    /// heroHost.view(for: appStore.projection(
    ///     action: AppAction.prism.heroDetails.review,
    ///     state:  AppState.lens.heroDetails.get
    /// ))
    /// ```
    ///
    /// Internally, the feature's `mapAction` and `mapState` project the store further down
    /// to the `ViewModel` types. The concrete `Content` view type is erased — callers
    /// receive `some View`.
    @MainActor
    public func view(for store: some StoreType<Action, State>) -> some View {
        _makeView(store)
    }
}
#endif
