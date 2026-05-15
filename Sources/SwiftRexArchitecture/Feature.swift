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
/// ## Full example — Movies list with API calls
///
/// ```swift
/// // ── Domain namespace ──────────────────────────────────────────────────────────
///
/// enum Domain {
///     struct Actor:     Sendable, Decodable { let id: String; let name: String }
///     struct Character: Sendable, Decodable { let name: String; let actor: Actor }
///     struct Movie:     Sendable, Decodable, Identifiable {
///         let id: String; let title: String
///         let isFavorite: Bool; let year: Int
///         let characters: [Character]
///     }
///
///     // Unified network error — four cases covering all failure modes.
///     enum NetworkError: Error, @unchecked Sendable {
///         case api(APIError)              // HTTP / connectivity failure
///         case encoding(EncodingError)    // failed to encode a request body
///         case decoding(DecodingError)    // failed to decode a response
///         case unknown(any Error)         // catch-all for unexpected failures
///     }
/// }
///
/// // ── App-level wrapper types ───────────────────────────────────────────────────
///
/// @Prisms                                     // generates AppAction.prism.movies
/// enum AppAction: Sendable {
///     case movies(MoviesFeature.Action)
/// }
///
/// @Lenses                                     // generates AppState.lens.movies
/// struct AppState: Sendable {
///     var movies = MoviesFeature.initialState()
/// }
///
/// // AppEnvironment holds infrastructure; feature environments hold pre-baked closures.
/// // .live(network: URLSession.shared.dataTask, decoderFactory: JSONDecoder(), encoderFactory: JSONEncoder())
/// struct AppEnvironment: Sendable {
///     var network:        APIClient
///     var decoderFactory: DataDecoderFactory
///     var encoderFactory: DataEncoderFactory
/// }
///
/// // ── Feature ───────────────────────────────────────────────────────────────────
///
/// enum MoviesFeature: Feature {
///
///     // Internal domain state
///     struct State: Sendable {
///         var movies:    [Domain.Movie]       = []
///         var isLoading: Bool                 = false
///         var error:     Domain.NetworkError? = nil
///     }
///
///     // Internal domain actions
///     enum Action: Sendable {
///         case fetchMovies                                                  // user pulls to refresh
///         case moviesResponse(Result<[Domain.Movie], Domain.NetworkError>)  // GET result
///         case toggleFavorite(String)                                       // movie.id — initiates POST
///         case favoriteResponse(Result<Domain.Movie, Domain.NetworkError>)  // POST result
///     }
///
///     // Feature environment: pre-baked closures — no APIClient or encoder/decoder knowledge.
///     // Constructed once in liftEnvironment; easy to stub in tests.
///     struct Environment: Sendable {
///         var fetchMovies:    @Sendable () async -> Result<[Domain.Movie], Domain.NetworkError>
///         var toggleFavorite: @Sendable (String) async -> Result<Domain.Movie, Domain.NetworkError>
///     }
///
///     // ── ViewModel (view-facing types) ─────────────────────────────────────────
///
///     @ViewModel
///     final class ViewModel {
///
///         struct ViewState: Sendable, Equatable {
///             struct MovieRow: Identifiable, Sendable, Equatable {
///                 var id:       String
///                 var title:    String   // "The Avengers (2012)"
///                 var subtitle: String   // "Spider-Man by Tom Holland, Thor by Chris Hemsworth"
///                 var starred:  Bool
///             }
///             var rows:      [MovieRow]
///             var isLoading: Bool
///             var error:     String?
///         }
///
///         enum ViewAction: Sendable {
///             case onAppear                    // view appeared → triggers initial fetch
///             case didTapStar(id: String)      // movie.id — different name, same value type
///         }
///     }
///
///     // ── Mappings ──────────────────────────────────────────────────────────────
///
///     static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { state in
///         .init(
///             rows: state.movies.map { movie in
///                 .init(
///                     id: movie.id,
///                     title: "\(movie.title) (\(movie.year))",  // title + Int year → String
///                     subtitle: movie.characters                // [Character] → single String
///                         .map { "\($0.name) by \($0.actor.name)" }
///                         .joined(separator: ", "),
///                     starred:  movie.isFavorite
///                 )
///             },
///             isLoading: state.isLoading,
///             error:     state.error.map { $0.localizedDescription }
///         )
///     }
///
///     static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { viewAction in
///         switch viewAction {
///         case .onAppear:           .fetchMovies           // onAppear, load the movies
///         case .didTapStar(let id): .toggleFavorite(id)    // onTapStar, toggle the favorite status of that movie
///         }
///     }
///
///     // ── Lifecycle ─────────────────────────────────────────────────────────────
///
///     static func initialState() -> State { .init() }
///
///     static func behavior() -> Behavior<Action, State, Environment> {
///         .handle { action, _ in
///             switch action.action {
///             case .fetchMovies:
///                 .reduce { $0.isLoading = true }
///                 .produce { env in
///                     .task { .moviesResponse(await env.fetchMovies()) }
///                 }
///             case .moviesResponse(.success(let movies)):
///                 .reduce { $0.movies = movies; $0.isLoading = false }
///             case .moviesResponse(.failure(let err)):
///                 .reduce { $0.error = err; $0.isLoading = false }
///             case .toggleFavorite(let id):
///                 .produce { env in 
///                     .task { .favoriteResponse(await env.toggleFavorite(id)) } 
///                 }
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
///
/// // ── FeatureHost convenience ───────────────────────────────────────────────────
/// //
/// // Declare alongside MoviesFeature so callers write `.movies` everywhere.
///
/// extension FeatureHost
/// where Action      == MoviesFeature.Action,
///       State       == MoviesFeature.State,
///       Environment == MoviesFeature.Environment {
///     static var movies: Self { .init(MoviesFeature.self) }
/// }
///
/// // ── Parent-store integration ──────────────────────────────────────────────────
///
/// let appStore = Store(
///     initial: AppState(),
///     behavior: FeatureHost.movies.behavior
///         .liftAction(AppAction.prism.movies)           // Prism — embed + extract
///         .liftState(AppState.lens.movies)              // Lens  — read + write
///         .liftEnvironment { appEnv in
///             let decoder = appEnv.decoderFactory
///             return MoviesFeature.Environment(
///                 fetchMovies: {
///                     await appEnv.network
///                         .get(from: "/movies", decoder: decoder.dataDecoder(for: [Domain.Movie].self))
///                         .mapError(Domain.NetworkError.init)
///                 },
///                 toggleFavorite: { id in
///                     await appEnv.network
///                         .post(to: "/movies/\(id)/favorite", decoder: decoder.dataDecoder(for: Domain.Movie.self))
///                         .mapError(Domain.NetworkError.init)
///                 }
///             )
///         },
///     environment: AppEnvironment(
///         network: URLSession.shared.apiClient(base: "https://api.example.com"),
///         decoderFactory: JSONDecoder(),
///         encoderFactory: JSONEncoder()
///     )
/// )
///
/// // Build the view when navigation shows the feature:
/// let view = FeatureHost.movies.view(for: appStore.projection(
///     action: AppAction.prism.movies.review,    // Prism — embed direction: (Action) -> AppAction
///     state:  AppState.lens.movies.get          // Lens  — get direction:   (AppState) -> State
/// ))
/// ```
///
/// ## Data flow
///
/// ```
/// AppStore<AppAction, AppState>
///   → projection(action: AppAction.movies, state: \.movies)
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
#endif
