#if canImport(Observation)
import Observation
import SwiftRex

// MARK: - Protocol

/// A SwiftUI view model that exposes a projected slice of store state as individually
/// `@Observable`-tracked properties, giving true field-level view invalidation.
///
/// Apply `@ViewModel` to a class that declares a nested `struct ViewState` and
/// `enum ViewAction`. The macro synthesises all observation infrastructure, the store
/// subscription, and the dispatch path — the class body stays empty:
///
/// ```swift
/// @ViewModel
/// final class CounterViewModel {
///     struct ViewState: Sendable, Equatable {
///         var count: String
///         var display: String
///     }
///     enum ViewAction: Sendable {
///         case tappedPlus
///         case tappedMinus
///     }
/// }
/// ```
///
/// The macro generates `var count: String`, `var display: String` as individually
/// `@Observable`-tracked computed properties on the class, plus an
/// `init(store: some StoreType<ViewAction, ViewState>)` that seeds them and subscribes.
///
/// When used with ``Feature``, declare the class nested inside the feature:
///
/// ```swift
/// enum CounterFeature: Feature {
///     // ...State, Action, Environment...
///
///     @ViewModel
///     final class ViewModel {
///         struct ViewState: Sendable, Equatable {
///             var count: String
///             var display: String
///         }
///         enum ViewAction: Sendable { case tappedPlus, tappedMinus }
///     }
///
///     static let mapState: @MainActor @Sendable (State) -> ViewModel.ViewState = { s in
///         .init(count: "\(s.count)", display: "\(s.label): \(s.count)")
///     }
///     static let mapAction: @Sendable (ViewModel.ViewAction) -> Action = { va in
///         switch va { case .tappedPlus: .increment; case .tappedMinus: .decrement }
///     }
///
///     typealias Content = CounterView
/// }
/// ```
///
/// ## Field-level invalidation
///
/// Each `ViewState` field becomes a separate `@Observable`-tracked property. SwiftUI
/// registers per-property dependencies during `body` evaluation, so a view reading only
/// `viewModel.count` does not re-render when `viewModel.display` changes. This is
/// fundamentally different from `ObservableObject`, which invalidates every observer
/// on any `@Published` change regardless of which property was read.
///
/// ## What the macro generates
///
/// - `ObservationRegistrar` and `Observable` conformance
/// - One `@Observable`-tracked computed property + private backing store per `ViewState` field
/// - `access(keyPath:)` and `withMutation(keyPath:)` required by `Observable`
/// - `init(store: some StoreType<ViewAction, ViewState>)` — seeds fields, subscribes,
///   and stores only a `dispatch` closure (not the whole store)
/// - `dispatch(_:file:function:line:)` — forwards via the captured closure with automatic
///   call-site capture for middleware provenance
///
/// ## Constraints enforced by the macro
///
/// - Attached type must be a `class`
/// - `ViewState` must be a `struct` declaration (not a `typealias`)
/// - `ViewAction` must be an `enum` declaration (not a `typealias`)
/// - `ViewState` must have at least one stored property
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public protocol ViewModel: AnyObject {
    associatedtype ViewState: Sendable & Equatable
    associatedtype ViewAction: Sendable

    /// Initialises the view model, subscribing to `store` and seeding all tracked fields.
    ///
    /// Synthesised by the `@ViewModel` macro. Declared here so ``Feature`` and
    /// ``FeatureHost`` can call it generically without knowing the concrete class.
    init(store: some StoreType<ViewAction, ViewState>)

    /// Dispatches a view action, capturing the call site for middleware provenance.
    ///
    /// The `file`, `function`, and `line` defaults are resolved at the call site —
    /// logging middleware always sees where the dispatch originated.
    func dispatch(_ action: ViewAction, file: String, function: String, line: UInt)
}

// MARK: - Macro

/// Synthesises all `Observable` infrastructure and store-wiring for a ``ViewModel``-conforming class.
///
/// Apply to a class that declares a nested `struct ViewState: Equatable` and `enum ViewAction`.
/// Both ``ViewModel`` and `Observable` conformances are added automatically — no other
/// annotations are needed.
///
/// See ``ViewModel`` for the full list of what is generated and the constraints that are enforced.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@attached(member, names:
    named(_$observationRegistrar),
    named(_dispatch),
    named(_token),
    named(access),
    named(withMutation),
    named(dispatch),
    named(init),
    arbitrary
)
@attached(extension, conformances: Observable, ViewModel)
public macro ViewModel() = #externalMacro(module: "SwiftRexMacros", type: "ViewModelMacro")
#endif
