#if canImport(Observation) && canImport(SwiftUI)
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI

/// A type-safe handle for a ``Feature`` that co-locates behavior and view in a single value.
///
/// `Module` is a 4-parameter generic: action, state, environment, and the concrete view type
/// (`Content`). Unlike the former `FeatureHost`, the view type is **not** erased to `AnyView` —
/// it flows through until you explicitly opt in to erasure with ``eraseToAnyView()``.
///
/// ## Creating a Module
///
/// Co-locate the typed ``Feature`` factory inside the feature's own module. `Feature.module`
/// is a free convenience defined on the protocol itself; you rarely need to declare your own:
///
/// ```swift
/// // HomeFeature module is now available as:
/// HomeFeature.module   // → Module<HomeFeature.Action, HomeFeature.State, HomeFeature.Environment, HomeView>
/// ```
///
/// ## Lifting to app types
///
/// ```swift
/// let lifted = HomeFeature.module.lift(
///     action:      AppAction.prism.home,
///     state:       AppState.lens.home,
///     environment: \.xmlDecoder >>> HomeFeature.Environment.init
/// )
/// lifted.behavior        // Behavior<AppAction, AppState, World>
/// lifted.view(for: store) // HomeView  — fully typed, no AnyView
/// ```
///
/// ## Routing boundary
///
/// When a single return type is required (e.g. a `switch` over routes), erase once:
///
/// ```swift
/// func module(for route: AppRoute) -> Module<AppAction, AppState, World, AnyView> {
///     switch route {
///     case .home:
///         HomeFeature.module
///             .lift(action: AppAction.prism.home, state: AppState.lens.home, environment: ...)
///             .eraseToAnyView()
///     }
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct Module<Action: Sendable, State: Sendable, Environment: Sendable, Content: View>: Sendable {

    // MARK: - Stored properties

    /// The feature's reducer + effects, ready to be lifted and embedded in a parent ``Store``.
    public let behavior: Behavior<Action, State, Environment>

    /// Type-erased view factory — closed over the Feature's `ViewModel` and `Content` types.
    private let _makeView: @MainActor @Sendable (any StoreType<Action, State>) -> Content

    // MARK: - Init from Feature type

    /// Creates a `Module` from a ``Feature`` type. The concrete `Content` type is inferred
    /// from `F.Content` and flows through without erasure.
    ///
    /// This is the only place in the codebase where `F.ViewModel`, `F.Content`, `F.mapState`,
    /// and `F.mapAction` are referenced. After this call they are sealed inside `_makeView`.
    ///
    /// - Parameter feature: The `Feature` metatype — e.g. `HeroDetailsFeature.self`.
    public init<F: Feature>(_ feature: F.Type)
    where F.Action == Action, F.State == State, F.Environment == Environment, F.Content == Content {
        behavior = F.behavior()
        _makeView = { @MainActor store in
            let vm = F.ViewModel(store: store.projection(
                action: F.mapAction,
                state:  F.mapState
            ))
            return F.Content(viewModel: vm)
        }
    }

    // MARK: - Internal init (used by lift and eraseToAnyView)

    init(
        behavior: Behavior<Action, State, Environment>,
        view: @escaping @MainActor @Sendable (any StoreType<Action, State>) -> Content
    ) {
        self.behavior = behavior
        _makeView    = view
    }

    // MARK: - View production

    /// Returns the feature's view wired to the given store.
    ///
    /// Pass any `StoreType` whose `Action` and `State` match this module's type parameters —
    /// typically a projection of a parent store scoped to the feature's slice.
    ///
    /// - Parameter store: A store (or projection) whose `Action` and `State` match this module.
    /// - Returns: The concrete `Content` view — no `AnyView` wrapping.
    @MainActor
    public func view(for store: some StoreType<Action, State>) -> Content {
        _makeView(store)
    }

    // MARK: - Lifting

    /// Lifts all three axes simultaneously — action prism, state lens, environment contramap —
    /// and returns a new `Module` that speaks the parent store's language while producing the
    /// same concrete `Content` view.
    ///
    /// ```swift
    /// let lifted = CalculatorFeature.module.lift(
    ///     action:      AppAction.prism.calculator,
    ///     state:       AppState.lens.calculator,
    ///     environment: \.solver >>> CalculatorFeature.Environment.init
    /// )
    /// store.install(lifted.behavior)  // Behavior<AppAction, AppState, World>
    /// lifted.view(for: appStore)      // CalculatorView — still typed
    /// ```
    ///
    /// - Parameters:
    ///   - action: A `Prism<GA, Action>` embedding the feature action into the global action.
    ///   - state:  A `Lens<GS, State>` projecting the global state to the feature slice.
    ///   - environment: A closure projecting the global environment to the feature environment.
    /// - Returns: A `Module<GA, GS, GE, Content>` ready for the parent store.
    public func lift<GA: Sendable, GS: Sendable, GE: Sendable>(
        action: Prism<GA, Action>,
        state:  Lens<GS, State>,
        environment: @escaping @Sendable (GE) -> Environment
    ) -> Module<GA, GS, GE, Content> {
        let makeView = _makeView
        return Module<GA, GS, GE, Content>(
            behavior: behavior.lift(action: action, state: state, environment: environment),
            view: { @MainActor @Sendable store in
                makeView(store.projection(action: action.review, state: state.get))
            }
        )
    }

    // MARK: - Content type erasure

    /// Erases the concrete `Content` type to `AnyView`.
    ///
    /// Use this only at the routing boundary where a switch over different routes must return a
    /// single homogeneous type. Prefer keeping the typed `Content` everywhere else.
    ///
    /// ```swift
    /// HomeFeature.module
    ///     .lift(action: AppAction.prism.home, state: AppState.lens.home, environment: ...)
    ///     .eraseToAnyView()   // → Module<AppAction, AppState, World, AnyView>
    /// ```
    public func eraseToAnyView() -> Module<Action, State, Environment, AnyView> {
        let makeView = _makeView
        return Module<Action, State, Environment, AnyView>(
            behavior: behavior,
            view: { @MainActor @Sendable store in AnyView(makeView(store)) }
        )
    }
}

// MARK: - AnyView-erasing Feature init

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public extension Module where Content == AnyView {

    /// Creates an AnyView-erased `Module` from a ``Feature`` type.
    ///
    /// Prefer `Feature.module` (which preserves the concrete view type). This init is retained
    /// for sites that explicitly need a `Module<..., AnyView>` without a separate `.eraseToAnyView()` call.
    init<F: Feature>(_ feature: F.Type)
    where F.Action == Action, F.State == State, F.Environment == Environment {
        behavior = F.behavior()
        _makeView = { @MainActor store in
            let vm = F.ViewModel(store: store.projection(
                action: F.mapAction,
                state:  F.mapState
            ))
            return AnyView(F.Content(viewModel: vm))
        }
    }
}

// MARK: - Deprecated FeatureHost alias

/// `FeatureHost` has been renamed `Module`.
///
/// The alias is kept so existing code compiles without changes; migrate to
/// `Module<Action, State, Environment, AnyView>` (or the typed form) at your convenience.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@available(*, deprecated, renamed: "Module")
public typealias FeatureHost<Action: Sendable, State: Sendable, Environment: Sendable> =
    Module<Action, State, Environment, AnyView>

#endif
