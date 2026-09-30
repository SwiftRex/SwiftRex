// SPDX-License-Identifier: Apache-2.0

/// How a ``ViewStore`` signals SwiftUI. Chosen once, by its **owner** (``OwnedStore``, ``ProjectionKeeper``,
/// `@Feature`) — receivers hold the ``ViewStore`` as a plain `let` and never see it.
///
/// Every strategy tracks the same thing — the key paths each view read — and differs only in the signal:
///
/// | Case | Signal | Invalidates |
/// | --- | --- | --- |
/// | ``automatic`` (default) | ``observation`` on iOS 17+, ``combine`` below | — |
/// | ``observation`` | Observation registrar, per changed path | only views that read a changed path |
/// | ``combine`` | one `objectWillChange` when a read path changed | every view observing the store |
///
/// A plain value type carrying no platform dependency, so it stays available everywhere.
public enum ViewStrategy: Sendable, Equatable {
    /// Observation where the OS has it (iOS 17, macOS 14, tvOS 17, watchOS 10), Combine below — the default.
    case automatic

    /// Observation-framework invalidation, per key path — only the views that read a changed path redraw.
    /// On systems without the Observation framework it falls back to ``combine`` signalling.
    case observation

    /// A Combine `objectWillChange`, sent only when a path some view read has changed; every view observing
    /// the store redraws on it. Forces Combine even where Observation is available — for code that listens
    /// to `objectWillChange`, or to sidestep the Observation framework.
    case combine
}
