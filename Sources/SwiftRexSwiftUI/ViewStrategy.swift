// SPDX-License-Identifier: Apache-2.0

/// How a feature's view observes its store — the storage/observation strategy `@Feature` builds and
/// `@BoundTo` binds to.
///
/// All three present the identical surface to the view — `viewStore.state.field` and
/// `viewStore.dispatch(_:)` — and differ only in the observation mechanism (and its platform floor):
///
/// | Case | Store | Invalidation | Floor | View holds it as |
/// | --- | --- | --- | --- | --- |
/// | ``observationSimple`` | `ViewStore` | whole-state | iOS 17 | `let` (Observation) |
/// | ``observationGranular`` | `TrackedViewStore` | per field | iOS 17 | `let` (Observation) |
/// | ``combineObservable`` | `ObservableObjectStore` | whole-state | iOS 13 | `@ObservedObject` |
///
/// A plain value type carrying no platform dependency, so it stays available everywhere — only the
/// stores it names are `#if canImport`/`@available`-gated.
public enum ViewStrategy: Sendable {
    /// Coarse `@Observable` `ViewStore` — whole-state invalidation (SwiftUI's structural diffing
    /// keeps redraws granular regardless). iOS 17+.
    case observationSimple

    /// Field-level `@Observable` `TrackedViewStore`. `@Feature` attaches `@Tracked` to the nested
    /// `ViewState` automatically. iOS 17+.
    case observationGranular

    /// Combine `ObservableObjectStore` bound via `@ObservedObject` — coarse, but works back to
    /// iOS 13, so it's the choice for pre-Observation deployment targets.
    case combineObservable
}
