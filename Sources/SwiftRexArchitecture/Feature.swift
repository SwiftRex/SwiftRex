#if canImport(Observation)
import Observation
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI

/// An opinionated module boundary that co-locates every concern of a single feature screen.
///
/// A `Feature` is typically an uninhabited `enum` namespace. It owns its internal `State`,
/// `Action`, and `Environment`; declares the view-layer `@ViewModel` class inline; and
/// bridges the two layers with `mapState` / `mapAction`.
///
/// For a complete end-to-end example including domain types, app-level wrappers,
/// `FeatureHost` integration, and the view, see the
/// [SwiftRex Architecture section in the README](https://github.com/SwiftRex/SwiftRex#swiftrex-architecture).
///
/// ## Feature body
///
/// ```swift
/// enum MoviesFeature: Feature {
///
///     struct State: Sendable {
///         var movies:    [Domain.Movie]       = []
///         var isLoading: Bool                 = false
///         var error:     Domain.NetworkError? = nil
///     }
///
///     enum Action: Sendable {
///         case fetchMovies
///         case moviesResponse(Result<[Domain.Movie], Domain.NetworkError>)
///         case toggleFavorite(String)                                        // movie.id
///         case favoriteResponse(Result<Domain.Movie, Domain.NetworkError>)
///     }
///
///     struct Environment: Sendable {
///         var fetchMovies:    @Sendable () async -> Result<[Domain.Movie], Domain.NetworkError>
///         var toggleFavorite: @Sendable (String) async -> Result<Domain.Movie, Domain.NetworkError>
///     }
///
///     @ViewModel
///     final class ViewModel {
///         struct ViewState: Sendable, Equatable {
///             struct MovieRow: Identifiable, Sendable, Equatable {
///                 var id: String; var title: String; var subtitle: String; var starred: Bool
///             }
///             var rows: [MovieRow]; var isLoading: Bool; var error: String?
///         }
///         enum ViewAction: Sendable {
///             case onAppear
///             case didTapStar(id: String)
///         }
///     }
///
///     static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
///         .init(
///             rows: state.movies.map { m in
///                 .init(id: m.id,
///                       title: "\(m.title) (\(m.year))",
///                       subtitle: m.characters.map { "\($0.name) by \($0.actor.name)" }.joined(separator: ", "),
///                       starred: m.isFavorite)
///             },
///             isLoading: state.isLoading,
///             error: state.error.map { $0.localizedDescription }
///         )
///     }
///
///     static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { viewAction in
///         switch viewAction {
///         case .onAppear:           .fetchMovies
///         case .didTapStar(let id): .toggleFavorite(id)
///         }
///     }
///
///     static func initialState() -> State { .init() }
///
///     static func behavior() -> Behavior<Action, State, Environment> {
///         .handle { action, _ in
///             switch action.action {
///             case .fetchMovies:
///                 .reduce { $0.isLoading = true }
///                 .produce { env in .task { .moviesResponse(await env.fetchMovies()) } }
///             case .moviesResponse(.success(let movies)):
///                 .reduce { $0.movies = movies; $0.isLoading = false }
///             case .moviesResponse(.failure(let err)):
///                 .reduce { $0.error = err; $0.isLoading = false }
///             case .toggleFavorite(let id):
///                 .produce { env in .task { .favoriteResponse(await env.toggleFavorite(id)) } }
///             case .favoriteResponse(.success(let movie)):
///                 .reduce { $0.movies = [Domain.Movie].ix(id: movie.id).set($0.movies, movie) }
///             case .favoriteResponse(.failure):
///                 .doNothing
///             }
///         }
///     }
///
///     typealias Content = MovieListView
/// }
/// ```
///
/// ## Data flow
///
/// ```
/// AppStore<AppAction, AppState>
///   → projection(action: AppAction.prism.movies.review, state: AppState.lens.movies.get)
///   → StoreProjection<MoviesFeature.Action, MoviesFeature.State>
///   → .projection(action: mapAction, state: mapState)            ← FeatureHost.view(for:)
///   → StoreProjection<ViewModel.ViewAction, ViewModel.ViewState>
///   → ViewModel.init(store:)                                     ← @ViewModel macro
///   → MovieListView(viewModel:)                                  ← HasViewModel
/// ```
///
/// ## Layer isolation
///
/// | Type | Knows | Never sees |
/// |---|---|---|
/// | `Feature` | State, Action, ViewModel, Content, mappings | Parent store types |
/// | `FeatureHost` | Action, State, Environment, Behavior | ViewModel, ViewState, ViewAction, Content |
/// | `ViewModel` | ViewState, ViewAction | State, Action, Environment |
/// | `Content` | ViewState, ViewAction (via `viewModel`) | All domain types |
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol Feature: Sendable {

    // MARK: - Internal types

    /// Full internal state. Never exposed beyond this feature boundary.
    associatedtype State: Sendable

    /// Full internal action set. Never exposed beyond this feature boundary.
    associatedtype Action: Sendable

    /// Live dependencies injected at build time (network, persistence, clocks…).
    associatedtype Environment: Sendable

    // MARK: - ViewModel

    /// The `@ViewModel`-annotated class that owns `ViewState` and `ViewAction` and drives the view.
    ///
    /// Declare it as a nested class named `ViewModel` — it becomes `MyFeature.ViewModel`. Swift
    /// infers this associated type from `Content.VM == ViewModel`, so no explicit `typealias` is
    /// needed when `Content` is provided.
    associatedtype ViewModel: SwiftRexSwiftUI.ViewModel

    // MARK: - Mappings

    /// Projects the full internal `State` to the view-facing `ViewModel.ViewState`.
    ///
    /// Must be `@MainActor @Sendable` — state is read on the main actor and the closure is
    /// captured inside a `StoreProjection`. Declare as a `static let` so it is computed once.
    static var mapState: @MainActor @Sendable (State) -> ViewModel.ViewState { get }

    /// Translates a `ViewModel.ViewAction` dispatched by the view into the internal `Action`.
    ///
    /// Pure value mapping — no actor isolation required. Declare as a `static let`.
    static var mapAction: @Sendable (ViewModel.ViewAction) -> Action { get }

    // MARK: - Lifecycle

    /// Returns the feature's initial state.
    ///
    /// Called by parent stores when seeding their initial `AppState` slice, and in tests
    /// when constructing a standalone store for this feature.
    static func initialState() -> State

    /// Returns the feature's `Behavior` — the reducer combined with any side-effect middleware.
    ///
    /// Called once by ``FeatureHost`` at creation time and stored in ``FeatureHost/behavior``
    /// for parent-store integration.
    static func behavior() -> Behavior<Action, State, Environment>

    // MARK: - View

    /// The concrete ``HasViewModel`` view this feature renders.
    ///
    /// The `Content.VM == ViewModel` constraint is a compile-time guarantee that the view's
    /// view model type matches the feature's. ``FeatureHost/build(store:)`` calls
    /// `Content(viewModel:)` directly via ``HasViewModel``.
    associatedtype Content: HasViewModel & View where Content.VM == ViewModel
}

// MARK: - Identity mapping defaults

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Feature where State == ViewModel.ViewState {
    /// Identity projection — no declaration needed when `State` is typealiased to `ViewModel.ViewState`.
    public static var mapState: @MainActor @Sendable (State) -> ViewModel.ViewState { { $0 } }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension Feature where Action == ViewModel.ViewAction {
    /// Identity translation — no declaration needed when `Action` is typealiased to `ViewModel.ViewAction`.
    public static var mapAction: @Sendable (ViewModel.ViewAction) -> Action { { $0 } }
}
#endif
