#if DEBUG && canImport(Observation)
import Observation
import SwiftRex
import SwiftRexSwiftUI
import Testing

/// A controllable, synchronous test harness for a ``Feature``-conforming type.
///
/// `TestFeature` wraps a ``TestStore`` and operates at the view-model layer: you dispatch
/// ``Feature/ViewModel`` `ViewAction`s (converted via `mapAction`) and assert on
/// ``Feature/ViewModel`` `ViewState` changes (mapped via `mapState`). Domain `State` and
/// domain `Action` are managed internally.
///
/// Effects still emit domain `Action`s from the behavior — use ``receive(_:sourceLocation:assert:)-8jfre``
/// or ``receive(_:sourceLocation:assert:)-3c7g4`` to match them via a `Prism` and assert the
/// resulting `ViewState`.
///
/// ## Typical flow
///
/// ```swift
/// @Test @MainActor
/// func fetchMovies_setsLoadingThenPopulatesRows() async {
///     let inception = Domain.Movie(id: "1", title: "Inception", isFavorite: false, year: 2010, characters: [])
///
///     let feature = TestFeature<MoviesFeature>(
///         environment: .init(
///             fetchMovies:    { .success([inception]) },
///             toggleFavorite: { _ in .failure(.unknown(CancellationError())) }
///         )
///     )
///
///     // dispatch a ViewAction; assert the resulting ViewState
///     feature.dispatch(.onAppear) { $0.isLoading = true }
///
///     await feature.runEffects()
///
///     // receive a domain action by Prism; assert ViewState
///     feature.receive(MoviesFeature.Action.prism.moviesResponse) { result, viewState in
///         if case .success(let movies) = result {
///             viewState.rows = /* expected rows */ []
///             viewState.isLoading = false
///         }
///     }
/// }
/// ```
///
/// ## Exhaustive mode
///
/// `TestFeature` is exhaustive by default (delegated to the underlying `TestStore`). Pass
/// `exhaustive: false` to opt out — the store will not fail when effects or received actions
/// are left unprocessed at deallocation.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public final class TestFeature<F: Feature> where F.State: Equatable {
    private let _store: TestStore<F.Action, F.State, F.Environment>

    /// The current domain state, after all dispatched and received actions have been processed.
    public var state: F.State { _store.state }

    /// The current view state derived from `state` via `F.mapState`.
    public var viewState: F.ViewModel.ViewState { F.mapState(_store.state) }

    // MARK: - Init

    /// Creates a `TestFeature` using the feature's default initial state.
    ///
    /// - Parameters:
    ///   - environment: The environment injected into effects.
    ///   - exhaustive: When `true` (default), enforces ordering and end-of-test checks.
    public init(environment: F.Environment, exhaustive: Bool = true) {
        _store = TestStore(
            initial: F.initialState(),
            behavior: F.behavior(),
            environment: environment,
            exhaustive: exhaustive
        )
    }

    /// Creates a `TestFeature` with a custom initial state (useful for mid-flow test scenarios).
    ///
    /// - Parameters:
    ///   - initial: The starting domain state.
    ///   - environment: The environment injected into effects.
    ///   - exhaustive: When `true` (default), enforces ordering and end-of-test checks.
    public init(initial: F.State, environment: F.Environment, exhaustive: Bool = true) {
        _store = TestStore(
            initial: initial,
            behavior: F.behavior(),
            environment: environment,
            exhaustive: exhaustive
        )
    }

    // MARK: - Dispatch

    /// Dispatches a `ViewAction` through the behavior (via `F.mapAction`) and validates the
    /// resulting `ViewState`.
    ///
    /// The `assert` closure receives an `inout` copy of the view state **before** the action and
    /// you mutate it to produce the expected post-action view state. A mismatch records a failure.
    ///
    /// - Parameters:
    ///   - viewAction: The view-layer action to dispatch.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action `ViewState` to produce the expected post-action value.
    ///     Pass `{ _ in }` when no view-state change is expected.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func dispatch(
        _ viewAction: F.ViewModel.ViewAction,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (inout F.ViewModel.ViewState) -> Void
    ) -> Self {
        let before = viewState
        _store.dispatch(F.mapAction(viewAction), sourceLocation: sourceLocation, assert: { _ in })
        assertViewState(
            before: before,
            after: viewState,
            label: "dispatch(\(viewAction))",
            sourceLocation: sourceLocation,
            expectedChange: expectedViewStateChange
        )
        return self
    }

    // MARK: - runEffects

    /// Executes all pending effects and collects their output actions into `receivedActions`.
    public func runEffects() async {
        await _store.runEffects()
    }

    // MARK: - receive

    /// Dequeues the next action from `receivedActions`, validates it via `prism`, runs it through
    /// the behavior, and validates the resulting `ViewState`.
    ///
    /// The `assert` closure receives both the **value extracted by the prism** and an `inout`
    /// copy of the view state before the action — use the extracted value when specifying what
    /// the view state should become:
    ///
    /// ```swift
    /// feature.receive(MoviesFeature.Action.prism.moviesResponse) { result, viewState in
    ///     if case .success(let movies) = result {
    ///         viewState.rows = expectedRows
    ///         viewState.isLoading = false
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A ``Prism`` matching the expected domain action case.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Receives the value extracted by `prism` and an `inout` copy of the
    ///     pre-action view state; mutate it to produce the expected post-action view state.
    @discardableResult
    public func receive<Value>(
        _ prism: Prism<F.Action, Value>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (Value, inout F.ViewModel.ViewState) -> Void
    ) -> F.Action? {
        guard !_store.receivedActions.isEmpty else {
            Issue.record(
                "receive() called but receivedActions is empty — call runEffects() first if you expect effect output",
                sourceLocation: sourceLocation
            )
            return nil
        }
        let next = _store.receivedActions.first!
        let extracted = prism.preview(next)
        let before = viewState
        _store.receive(prism, sourceLocation: sourceLocation, assert: { _, _ in })
        if let value = extracted {
            assertViewState(
                before: before,
                after: viewState,
                label: "receive(\(next))",
                sourceLocation: sourceLocation
            ) { expected in expectedViewStateChange(value, &expected) }
        }
        return next
    }

    /// Dequeues the next action from `receivedActions`, validates it via `prism` (no associated
    /// value), and validates the resulting `ViewState`.
    ///
    /// ```swift
    /// feature.receive(MoviesFeature.Action.prism.resetCompleted) { $0 = .init() }
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A ``Prism<Action, Void>`` matching an action case with no associated value.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action view state to produce the expected post-action value.
    @discardableResult
    public func receive(
        _ prism: Prism<F.Action, Void>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (inout F.ViewModel.ViewState) -> Void
    ) -> F.Action? {
        receive(prism, sourceLocation: sourceLocation) { (_, vs: inout F.ViewModel.ViewState) in
            expectedViewStateChange(&vs)
        }
    }

    // MARK: - Private

    private func assertViewState(
        before: F.ViewModel.ViewState,
        after: F.ViewModel.ViewState,
        label: String,
        sourceLocation: SourceLocation,
        expectedChange: (inout F.ViewModel.ViewState) -> Void
    ) {
        var expected = before
        expectedChange(&expected)
        guard after != expected else { return }
        Issue.record(
            """
            ViewState mismatch after \(label)
            Expected: \(expected)
              Actual: \(after)
            """,
            sourceLocation: sourceLocation
        )
    }
}

// MARK: - Convenience for Void environment

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension TestFeature where F.Environment == Void {
    /// Creates a `TestFeature` with a `Void` environment using the feature's default initial state.
    public convenience init(exhaustive: Bool = true) {
        self.init(environment: (), exhaustive: exhaustive)
    }

    /// Creates a `TestFeature` with a `Void` environment and a custom initial state.
    public convenience init(initial: F.State, exhaustive: Bool = true) {
        self.init(initial: initial, environment: (), exhaustive: exhaustive)
    }
}
#endif
