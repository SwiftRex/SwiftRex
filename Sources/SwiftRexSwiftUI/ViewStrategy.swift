// SPDX-License-Identifier: Apache-2.0

/// How an ``ObservableStore`` signals SwiftUI — and so how a view holds it. `@Feature` builds its store with
/// this strategy and `@BoundTo` injects the matching property.
///
/// Both strategies track the same thing — the key paths each view read — and differ only in the signal:
///
/// | Case | Signal | Invalidates | Floor | View holds it as |
/// | --- | --- | --- | --- | --- |
/// | ``observation`` | Observation registrar, per changed path | only views that read a changed path | iOS 17 | `let` / `@State` |
/// | ``combine`` | one `objectWillChange` when a read path changed | every view observing the store | iOS 13 | `@ObservedObject` / `@StateObject` |
///
/// A plain value type carrying no platform dependency, so it stays available everywhere.
public enum ViewStrategy: Sendable, Equatable {
    /// Observation-framework invalidation, per key path — only the views that read a changed path redraw.
    /// iOS 17+ (older systems fall back to ``combine`` signalling).
    case observation

    /// A Combine `objectWillChange`, sent only when a path some view read has changed. Every view observing
    /// the store redraws on that signal — the choice for pre-Observation deployment targets.
    case combine
}
