/// Diagnostic passed to ``StoreHooks/onReentranceDetected`` when a single dispatch cycle drains
/// more than ``StoreHooks/reentranceThreshold`` actions — the signature of a runaway re-dispatch
/// loop (e.g. a `willChange`/`didChange` observer that dispatches on every change).
public struct StoreReentranceInfo {
    /// How many actions the drain processed before tripping the threshold.
    public let drainedCount: Int
    /// The configured threshold that was exceeded.
    public let threshold: Int
    /// The call-site provenance of the next (un-processed) action when the trip happened.
    public let source: ActionSource?
    /// A textual description of that action — the hook is non-generic, so the typed action can't
    /// be carried directly.
    public let actionDescription: String?
}

/// Global, configurable hooks for ``Store`` diagnostics — modelled on RxSwift's `Hooks`.
///
/// `Store` is generic, so a true *global* static can't live on it (`Store<…>.member` is
/// per-specialisation); these live on a non-generic namespace instead. Configure them once at
/// startup — they are `@MainActor`, matching the Store's dispatch isolation.
public enum StoreHooks {
    /// Maximum number of actions a single synchronous dispatch cycle may drain before
    /// ``onReentranceDetected`` fires and the runaway queue is dropped. Default `1000`.
    ///
    /// Synchronous re-dispatch is rare — effects hop asynchronously — so only a genuine
    /// re-dispatch loop ever reaches this.
    @MainActor public static var reentranceThreshold: Int = 1_000

    /// Invoked when a dispatch cycle exceeds ``reentranceThreshold``. The default **traps in
    /// DEBUG** (`assertionFailure`) and is a no-op in release; either way the `Store` drops the
    /// runaway queue afterwards so the app can't hang. Replace it to log, record telemetry, etc.
    @MainActor public static var onReentranceDetected: @MainActor (StoreReentranceInfo) -> Void = { info in
        #if DEBUG
        assertionFailure(
            "SwiftRex: dispatch reentrance — drained \(info.drainedCount) actions in one cycle "
                + "(threshold \(info.threshold)). Likely an observer re-dispatching in a loop. "
                + "Next action: \(info.actionDescription ?? "?") from \(info.source.map(String.init(describing:)) ?? "?")."
        )
        #endif
    }
}
