#if canImport(Observation) && canImport(SwiftUI)
import Observation
import SwiftRex
import SwiftRexArchitecture
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

    /// Calls ``flush()`` then runs `body` while the underlying ``TestStore`` is frozen:
    /// any ``TestStore/dispatch(_:source:)`` from the view layer is a no-op for the
    /// lifetime of the closure.
    ///
    /// Designed for snapshot helpers — `assertSnapshot` instantiates a fresh
    /// `UIHostingController` per call which fires SwiftUI lifecycle hooks
    /// (`.onAppear`, `.task`) that would otherwise enqueue view actions and pollute
    /// the test's queue. Use it like:
    ///
    /// ```swift
    /// await feature.ignoringActions {
    ///     assertSnapshot(of: feature.view, as: .image(...))
    /// }
    /// ```
    public func ignoringActions(_ body: @MainActor () async throws -> Void) async rethrows {
        await flush()
        _store.isIgnoringActions = true
        defer { _store.isIgnoringActions = false }
        try await body()
    }

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

    /// Translates `viewAction` via `F.mapAction` and enqueues the resulting domain action into
    /// `receivedActions`, then returns a ``FeatureStep`` for the rest of the cycle.
    ///
    /// Unlike a direct dispatch, the domain action is **not** run through the behavior immediately —
    /// it sits as the first entry in the received queue. This keeps the full cycle symmetric:
    /// every domain action goes through ``FeatureStep/receive(_:sourceLocation:assert:)-6u6eu``,
    /// so assertions and effects are always declared in the same place.
    ///
    /// ```swift
    /// // dispatch(.onAppear) enqueues .fetchMovies as the first received action.
    /// // receive() runs .fetchMovies through the behavior (isLoading = true, effect produced).
    /// // runEffects() drives the network effect → .moviesResponse lands in the queue.
    /// // receive() runs .moviesResponse through the behavior (rows populated).
    ///
    /// let step = feature.dispatch(.onAppear)
    /// step.receive(Action.prism.fetchMovies) { _, vs in vs.isLoading = true }
    /// await step.runEffects()
    /// step.receive(Action.prism.moviesResponse) { result, vs in
    ///     vs.isLoading = false
    /// }
    /// ```
    ///
    /// The ``FeatureStep``'s `deinit` records a failure if effects or received actions are left
    /// unprocessed, so the full cycle must always be declared.
    ///
    /// - Parameters:
    ///   - viewAction: The view-layer action to translate and enqueue.
    /// - Returns: A ``FeatureStep`` for chaining ``FeatureStep/receive(_:sourceLocation:assert:)-6u6eu``
    ///   and ``FeatureStep/runEffects()``.
    @discardableResult
    public func dispatch(_ viewAction: F.ViewModel.ViewAction) -> FeatureStep<F> {
        _store.enqueue(F.mapAction(viewAction))
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
        let before = viewState
        guard let (action, value) = _store._dequeueAndRun(prism, sourceLocation: sourceLocation) else {
            return nil
        }
        assertViewState(
            before: before,
            after: viewState,
            label: "receive(\(action))",
            sourceLocation: sourceLocation
        ) { expected in expectedViewStateChange(value, &expected) }
        return action
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

    /// The owning ``TestFeature``. Exposed so helpers in test code (e.g. snapshot
    /// chain operators) can reach the view and the ignore-actions hook.
    public var feature: TestFeature<F> { _feature }

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
        syncCounts()
        return self
    }

    private func syncCounts() {
        _pendingCount = _feature._store.pendingEffects.count
        _receivedCount = _feature._store.receivedActions.count
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
        syncCounts()
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
        syncCounts()
        return self
    }

    // MARK: - mapped(to:)
    //
    // Reads like the test reads: `dispatch(viewAction).mapped(to: prism) { ... }`
    // asserts the result of the view-action → domain-action mapping. Mechanically
    // identical to ``receive(_:sourceLocation:assert:)-6u6eu``, but the name draws
    // a line between the first hop (view layer) and subsequent receives (effects).

    /// First receive after ``TestFeature/dispatch(_:)``: validates the view-action →
    /// domain-action `mapAction` produced the case named by `prism`, runs it through
    /// the behavior, and asserts the resulting `ViewState`.
    @discardableResult
    public func mapped<Value>(
        to prism: Prism<F.Action, Value>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (Value, inout F.ViewModel.ViewState) -> Void
    ) -> Self {
        receive(prism, sourceLocation: sourceLocation, assert: expectedViewStateChange)
    }

    /// First receive after ``TestFeature/dispatch(_:)`` for a no-associated-value action case.
    @discardableResult
    public func mapped(
        to prism: Prism<F.Action, Void>,
        sourceLocation: SourceLocation = #_sourceLocation,
        assert expectedViewStateChange: (inout F.ViewModel.ViewState) -> Void
    ) -> Self {
        receive(prism, sourceLocation: sourceLocation, assert: expectedViewStateChange)
    }
}
#endif
