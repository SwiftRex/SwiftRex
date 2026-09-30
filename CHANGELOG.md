# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `StateStream<State>` — a store's state over time, lazy and main-actor: `observe { }` delivers the current
  state during the call, then every new state; `subscribe(onChange:)`; `map` / `removeDuplicates`; an
  `AsyncSequence` that keeps only the latest value. `UISubscriptionToken` — its main-actor cancellation
  handle, cancelling synchronously (also on release).
- Bridges make `StateStream` the framework's own type: a Combine `Publisher` (demand honoured with the latest
  value), an RxSwift `ObservableType`, a ReactiveSwift `SignalProducerConvertible`, and `asPublisher` for
  ReactiveConcurrency. All deliver the current state first, on the main actor.
- Granular SwiftUI reads (`SwiftRex.SwiftUI`): `ViewStore<Action, State>` — the only readable store —
  keeps one snapshot and a dependency per key path each view read through `viewStore.state`, signalling only
  what changed (compared with `==`), at any depth. `GranularTracking` (a position in the state, `each(_:)`
  for list rows), `IndivisibleTracking` (types read whole), `viewStore.focus(.state(…), .action(…))` (a
  key-path slice with its own action lane), owners `@OwnedStore` and `ProjectionKeeper`.
- `ViewStrategy.automatic` (default): Observation on iOS 17+, Combine below, decided at runtime.
- `read(derived:)` — depend on a computed value instead of the whole state.
- `transpose()` everywhere, depending on the presence edge only: on `ViewStore`, `ViewStore<T?>` (or
  `ViewStore<Presentation<T>>`) becomes `ViewStore<T>?` on the same engine; on any store, a
  `StateStream<StoreProjection<A, T>?>` that emits a child store when the value appears and `nil` when it goes
  away (for UIKit and other non-SwiftUI renderers). `transpose(action:state:)` on `ViewStore` for closure lanes.
- `Binding<Presentation<T>>` from `binding(.state(\.slot), dismiss:)`, carrying both dismiss edges:
  `.sheet(item:)` takes it directly; `.isPresented()`, `.item()` and `.onDismiss()` feed any other container.
- Articles: *Stores at a Glance*, *Observing a Store in SwiftUI*.

### Changed
- **Breaking:** `StoreType` is `dispatch(_:source:)` + `stateStream`. There is no `state` on a store (a
  `Store`'s is private; `TestStore.state` stays) and no `observe(willChange:didChange:)` — a store is
  followed, not read; views read through a `ViewStore`. `StoreBuffer` is a struct with no shared cache.
- **Breaking:** bindings live on `ViewStore` only — they no longer compile on a raw `Store` or
  `StoreProjection`, which SwiftUI can't observe — and they share one name: `presence` and `item` are
  `binding(_:dismiss:)` (typed `Binding<Bool>` / `Binding<T?>` by the SwiftUI parameter), and the
  `presenting` / `presentingItem` modifiers are `.sheet(item:)` with a `Binding<Presentation<T>>`. A
  transposed child is a view store holding its last present value while it is dismissed.
- **Breaking:** `@BoundTo(Feature.self)` takes no `strategy:` and injects `let viewStore: ViewStore<…>`;
  `@Feature(strategy:)` defaults to `.automatic`; generated views and `Feature` conformances are no longer
  availability-gated. The generated view owns its view store once per view identity (a `ProjectionKeeper`),
  buffered before the map when `State: Equatable`.
- **Breaking:** `ViewStrategy` cases are `.automatic` / `.observation` / `.combine`.
- Bumped dependencies to their first stable majors: FP → 2.0.1, Hourglass → 1.0.1,
  ReactiveConcurrency → 1.0.0. No SwiftRex source changes were required — none of the majors'
  breaking changes touch APIs SwiftRex consumes.
- Tooling standardized to Swift 6.3 / Xcode 26.5; added SwiftFormat, SPDX headers, and Apache
  license attribution.

### Fixed
- Navigation built on a raw `Store` silently never updated; bindings and presentation now require a
  `ViewStore`, which does.
- A transposed child screen holds its last present value while it is dismissed, instead of the value it had
  when `transpose()` last ran.

### Removed
- **Breaking:** the old `ViewStore` class, `TrackedViewStore`, `@Tracked`, `ObservableObjectStore`,
  `asObservableObject()`, `store.publisher`, `store.stream`, the core `StoreType.transpose()` and `peek` in
  views (dispatch the intent instead) — see *Stores at a Glance* → "Removed — and what replaced them".
- Dropped the XCFramework release path entirely — the pre-built binary artifacts were broken and
  unused. SwiftRex is distributed via Swift Package Manager only. Removes the `rc-build-xcframework`
  CI job and all XCFramework references from the README and the Installation article.

## [0.8.8] - 2026

- Latest tagged release of the redesigned `@Feature` + state-driven navigation API. See the
  [GitHub releases](https://github.com/SwiftRex/SwiftRex/releases) for the detailed history of the
  0.8.x line.

[Unreleased]: https://github.com/SwiftRex/SwiftRex/compare/v0.8.8...main
[0.8.8]: https://github.com/SwiftRex/SwiftRex/releases/tag/v0.8.8
