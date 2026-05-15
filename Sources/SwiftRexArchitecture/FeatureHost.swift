#if canImport(Observation)
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI

/// A type-erased handle for a ``Feature`` that exposes only its domain-level surface.
///
/// `FeatureHost` is the value a parent coordinator or navigation model holds. It knows the
/// domain types — `Action`, `State`, `Environment` — needed to integrate the feature's
/// reducer into a parent store, but erases all view-layer types at creation time. After
/// `init`, nothing outside can see `F.ViewModel`, `F.Content`, `F.ViewState`, or
/// `F.ViewAction`.
///
/// ## Responsibilities
///
/// A `FeatureHost` has exactly two jobs:
///
/// 1. **Expose the `Behavior`** so the parent store can embed the feature's reducer and
///    effects alongside its own.
/// 2. **Produce the view** on demand by accepting a projected `StoreType` and returning
///    an opaque `some View`.
///
/// ## Full usage example
///
/// ```swift
/// // 1. Parent store types
/// struct AppState: Sendable {
///     var heroDetails: HeroDetailsFeature.State = HeroDetailsFeature.initialState()
/// }
/// enum AppAction: Sendable {
///     case heroDetails(HeroDetailsFeature.Action)
/// }
/// struct AppEnvironment: Sendable {
///     var hero: HeroDetailsFeature.Environment
/// }
///
/// // 2. Create the host — view generics vanish here
/// let heroHost = FeatureHost(HeroDetailsFeature.self)
///
/// // 3. Embed the feature's behavior in the parent
/// let appStore = Store(
///     initial: AppState(),
///     behavior: heroHost.behavior
///         .liftAction { (app: inout AppAction) -> HeroDetailsFeature.Action? in
///             guard case .heroDetails(let a) = app else { return nil }
///             return a
///         }
///         .liftState(\.heroDetails)
///         .liftEnvironment(\.hero),
///     environment: AppEnvironment(...)
/// )
///
/// // 4. Show the feature's view when navigation demands it
/// NavigationLink("Hero Details") {
///     heroHost.view(for: appStore.projection(
///         action: AppAction.heroDetails,
///         state: \.heroDetails
///     ))
/// }
/// ```
///
/// ## Why not pass the environment to `view(for:)`?
///
/// The `Store` already owns the live dependencies. Passing the store is correct because
/// the feature's environment was injected when the parent `Store` was created —
/// `view(for:)` only needs the state+dispatch channel, not the environment again.
///
/// ## Generic erasure
///
/// `FeatureHost<Action, State, Environment>` is generic only over domain types. The
/// view-layer generics (`F.ViewModel`, `F.Content`, etc.) exist solely inside `init` and
/// are captured as closures — they do not appear anywhere on the struct's type after that.
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
