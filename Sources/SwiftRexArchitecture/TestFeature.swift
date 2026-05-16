#if DEBUG && canImport(Observation) && canImport(SwiftUI)
import Observation
import SwiftRex
import SwiftRexSwiftUI
import SwiftUI
import Testing

// MARK: - TestFeature

/// A controllable, synchronous test harness for a ``Feature``-conforming type.
///
/// `TestFeature` wraps a ``TestStore`` and operates at the view-model layer: you dispatch
/// ``Feature/ViewModel`` `ViewAction`s (converted via `mapAction`) and assert on
/// ``Feature/ViewModel`` `ViewState` changes (mapped via `mapState`). Domain `State` and
/// domain `Action` are managed internally.
///
/// ``dispatch(_:sourceLocation:assert:)`` returns a ``FeatureStep`` whose `deinit` records
/// a failure if any pending effects were not run or any received actions were not processed,
/// so the full dispatch → effect → receive cycle must be declared explicitly:
///
/// ```swift
/// // Pure action — no effects; step deinit sees empty queues → OK
/// feature.dispatch(.increment) { $0.count = 1 }
///
/// // Action with effects — must chain runEffects() + receive()
/// let step = feature.dispatch(.onAppear) { $0.isLoading = true }
/// await step.runEffects()
/// step.receive(MoviesFeature.Action.prism.moviesResponse) { result, vs in
///     vs.isLoading = false
/// }
/// ```
///
/// ## View access for snapshot testing
///
/// `TestFeature` eagerly constructs ``Feature/Content`` and exposes it as ``view``. The
/// underlying ``TestStore`` conforms to ``StoreType``, so the ``Feature/ViewModel`` subscribes
/// to it and its `@Observable` properties update **synchronously** with each state mutation.
/// Call ``flush()`` before snapshotting to give SwiftUI one run-loop turn to process the changes.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public final class TestFeature<F: Feature> where F.State: Equatable {
    fileprivate let _store: TestStore<F.Action, F.State, F.Environment>
    private let _viewModel: F.ViewModel

    /// The feature's live view, driven by `_viewModel`.
    ///
    /// Pass this to any snapshot framework after calling ``flush()`` to allow SwiftUI to
    /// process the latest `@Observable` changes.
    public let view: F.Content

    /// The current domain state, after all dispatched and received actions have been processed.
    public var state: F.State { _store.state }

    /// The current view state derived from `state` via `F.mapState`.
    public var viewState: F.ViewModel.ViewState { F.mapState(_store.state) }

    // MARK: - Init

    /// Creates a `TestFeature` using the feature's default initial state.
    ///
    /// - Parameters:
    ///   - environment: The environment injected into effects.
    ///   - exhaustive: When `true` (default), each ``FeatureStep`` fails if effects or received
    ///     actions are left unprocessed when the step goes out of scope.
    public init(environment: F.Environment, exhaustive: Bool = true) {
        let store = TestStore(
            initial: F.initialState(),
            behavior: F.behavior(),
            environment: environment,
            exhaustive: exhaustive
        )
        let vm = F.ViewModel(store: store.projection(action: F.mapAction, state: F.mapState))
        _store = store
        _viewModel = vm
        view = F.Content(viewModel: vm)
    }

    /// Creates a `TestFeature` with a custom initial state (useful for mid-flow test scenarios).
    ///
    /// - Parameters:
    ///   - initial: The starting domain state.
    ///   - environment: The environment injected into effects.
    ///   - exhaustive: When `true` (default), enforces ordering and end-of-test checks.
    public init(initial: F.State, environment: F.Environment, exhaustive: Bool = true) {
        let store = TestStore(
            initial: initial,
            behavior: F.behavior(),
            environment: environment,
            exhaustive: exhaustive
        )
        let vm = F.ViewModel(store: store.projection(action: F.mapAction, state: F.mapState))
        _store = store
        _viewModel = vm
        view = F.Content(viewModel: vm)
    }

    // MARK: - flush

    /// Yields the current task so SwiftUI can process `@Observable` notifications queued
    /// during the last dispatch or receive.
    ///
    /// Because ``TestStore`` fires `willChange` / `didChange` **synchronously** inside each
    /// state mutation, the ``Feature/ViewModel``'s `@Observable` backing stores are already
    /// up-to-date when ``dispatch(_:sourceLocation:assert:)`` returns. `flush()` gives
    /// SwiftUI's render scheduler one run-loop turn to pick up those changes before you
    /// snapshot ``view``.
    ///
    /// ```swift
    /// feature.dispatch(.increment) { $0.count = 1 }
    /// await feature.flush()
    /// assertSnapshot(of: feature.view, as: .image(on: .iPhone16))
    /// ```
    public func flush() async {
        await Task.yield()
    }

    // MARK: - Dispatch

    /// Dispatches a `ViewAction` through the behavior (via `F.mapAction`), validates the
    /// resulting `ViewState`, and returns a ``FeatureStep`` for handling effects and received actions.
    ///
    /// The `assert` closure receives an `inout` copy of the view state **before** the action;
    /// mutate it to produce the expected post-action view state.
    ///
    /// The returned ``FeatureStep``'s `deinit` records a failure if:
    /// - effects were produced but ``FeatureStep/runEffects()`` was not called, or
    /// - received actions remain after effects ran but ``FeatureStep/receive(_:sourceLocation:assert:)-6u6eu``
    ///   was not called for each.
    ///
    /// For pure actions with no side effects the step can be discarded — its `deinit` sees
    /// empty queues and passes silently.
    ///
    /// ```swift
    /// // Pure — discard the step
    /// feature.dispatch(.increment) { $0.count = 1 }
    ///
    /// // With effects — must handle the full cycle
    /// let step = feature.dispatch(.onAppear) { $0.isLoading = true }
    /// await step.runEffects()
    /// step.receive(Action.prism.moviesResponse) { result, vs in
    ///     vs.isLoading = false
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - viewAction: The view-layer action to dispatch.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Mutates the pre-action `ViewState` to produce the expected post-action value.
    ///     Pass `{ _ in }` when no view-state change is expected.
    /// - Returns: A ``FeatureStep`` for chaining ``FeatureStep/runEffects()`` and
    ///   ``FeatureStep/receive(_:sourceLocation:assert:)-6u6eu``.
    @discardableResult
    public func dispatch(
        _ viewAction: F.ViewModel.ViewAction,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (inout F.ViewModel.ViewState) -> Void
    ) -> FeatureStep<F> {
        let before = viewState
        _store.dispatch(F.mapAction(viewAction), sourceLocation: sourceLocation, assert: { _ in })
        assertViewState(
            before: before,
            after: viewState,
            label: "dispatch(\(viewAction))",
            sourceLocation: sourceLocation,
            expectedChange: expectedViewStateChange
        )
        return FeatureStep(self)
    }

    // MARK: - receive

    /// Dequeues the next action from `receivedActions`, validates it via `prism`, runs it through
    /// the behavior, and validates the resulting `ViewState`.
    ///
    /// The `assert` closure receives both the **value extracted by the prism** and an `inout`
    /// copy of the view state before the action:
    ///
    /// ```swift
    /// feature.receive(MoviesFeature.Action.prism.moviesResponse) { result, viewState in
    ///     if case .success = result { viewState.isLoading = false }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - prism: A ``Prism`` matching the expected domain action case.
    ///   - sourceLocation: Captured automatically; points failures to the call site.
    ///   - assert: Receives the extracted value and an `inout` copy of the pre-action view state.
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

    // MARK: - Internal helpers (used by FeatureStep)

    fileprivate func assertViewState(
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

// MARK: - FeatureStep

/// The result of a ``TestFeature/dispatch(_:sourceLocation:assert:)`` call.
///
/// `FeatureStep` sequences the dispatch → effects → receive cycle and enforces completeness
/// via `deinit`: if the step is released while effects are pending or received actions remain
/// unprocessed, a `Testing` failure is recorded pointing to the call site.
///
/// ```swift
/// let step = feature.dispatch(.onAppear) { $0.isLoading = true }
/// await step.runEffects()
/// step.receive(MoviesFeature.Action.prism.moviesResponse) { result, vs in
///     vs.isLoading = false
/// }
/// // step goes out of scope: pending = 0, received = 0 → OK
/// ```
///
/// Alternatively, chain directly when there is exactly one received action per dispatch:
///
/// ```swift
/// let step = feature.dispatch(.onAppear) { $0.isLoading = true }
/// await step.runEffects()
/// step.receive(MoviesFeature.Action.prism.moviesResponse) { result, vs in
///     vs.isLoading = false
/// }
/// ```
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@MainActor
public final class FeatureStep<F: Feature> where F.State: Equatable {
    private let _feature: TestFeature<F>

    // Mirrored for nonisolated deinit — written on @MainActor, read only in deinit.
    nonisolated(unsafe) private var _pendingCount: Int
    nonisolated(unsafe) private var _receivedCount: Int

    init(_ feature: TestFeature<F>) {
        _feature = feature
        _pendingCount = feature._store.pendingEffects.count
        _receivedCount = feature._store.receivedActions.count
    }

    nonisolated deinit {
        if _pendingCount > 0 {
            Issue.record(
                "\(_pendingCount) pending effect(s) not run — call runEffects() on this FeatureStep"
            )
        } else if _receivedCount > 0 {
            Issue.record(
                "\(_receivedCount) received action(s) not processed — call receive() on this FeatureStep"
            )
        }
    }

    // MARK: - runEffects

    /// Executes all pending effects and collects their output actions into `receivedActions`.
    ///
    /// Must be called before ``receive(_:sourceLocation:assert:)-6u6eu`` when the dispatched
    /// action triggers async effects.
    ///
    /// - Returns: `self` for chaining ``receive(_:sourceLocation:assert:)-6u6eu``.
    @discardableResult
    public func runEffects() async -> Self {
        await _feature._store.runEffects()
        _pendingCount = 0
        _receivedCount = _feature._store.receivedActions.count
        return self
    }

    // MARK: - receive

    /// Dequeues the next action from `receivedActions`, validates it via `prism`, and asserts
    /// the resulting `ViewState`. Delegates to ``TestFeature/receive(_:sourceLocation:assert:)-6u6eu``.
    ///
    /// - Returns: `self` for chaining additional `receive` calls.
    @discardableResult
    public func receive<Value>(
        _ prism: Prism<F.Action, Value>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (Value, inout F.ViewModel.ViewState) -> Void
    ) -> Self {
        _feature.receive(prism, sourceLocation: sourceLocation, assert: expectedViewStateChange)
        _receivedCount = _feature._store.receivedActions.count
        return self
    }

    /// Dequeues the next action (no associated value), validates via `prism`, and asserts `ViewState`.
    /// Delegates to ``TestFeature/receive(_:sourceLocation:assert:)-2oy2y``.
    ///
    /// - Returns: `self` for chaining additional `receive` calls.
    @discardableResult
    public func receive(
        _ prism: Prism<F.Action, Void>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (inout F.ViewModel.ViewState) -> Void
    ) -> Self {
        _feature.receive(prism, sourceLocation: sourceLocation, assert: expectedViewStateChange)
        _receivedCount = _feature._store.receivedActions.count
        return self
    }
}
#endif
