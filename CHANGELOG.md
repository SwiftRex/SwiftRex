# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Granular SwiftUI observation (`SwiftRex.SwiftUI`): `ObservableStore` keeps one state snapshot and a
  dependency per key path each view read, signalling only what changed (compared with `==`), at any depth.
  `ViewStore` (the receiver, a plain `let`), `StateNode` (reads into a region), `ScopedStore`
  (`node.scoped(action:)`), `each(_:)` for list rows, `@ObservedStore` and `ObservableStoreHost` (owners),
  `ObservableLeaf`, `store.observable(_:)`.
- `ViewStrategy.automatic` (default): Observation on iOS 17+, Combine below, decided at runtime.
- `read(derived:)` — depend on a computed value instead of the whole state.
- `transpose(action:state:)` on observed stores — the closure-lane form, depending on the presence edge only.
- `StoreType.untrackedState` — follow a store without viewing it (what projections, buffers and child
  observed stores read).
- Articles: *Stores at a Glance*, *Observing a Store in SwiftUI*.

### Changed
- **Breaking:** binding and presentation helpers (`binding`, `presence`, `item`, `presenting`,
  `presentingItem`, `transpose` over `Presentation`, `hasScene`) moved from `StoreType` to
  `ObservableStoreType` — they no longer compile on a raw `Store` or `StoreProjection`, which SwiftUI can't
  observe.
- **Breaking:** `@BoundTo(Feature.self)` takes no `strategy:` and injects `let viewStore: ViewStore<…>`;
  `@Feature(strategy:)` defaults to `.automatic`; generated views and `Feature` conformances are no longer
  availability-gated. The generated view builds its store once per view identity, buffered before the map
  when `State: Equatable`.
- **Breaking:** `ViewStrategy` cases are `.automatic` / `.observation` / `.combine`.
- Bumped dependencies to their first stable majors: FP → 2.0.1, Hourglass → 1.0.1,
  ReactiveConcurrency → 1.0.0. No SwiftRex source changes were required — none of the majors'
  breaking changes touch APIs SwiftRex consumes.
- Tooling standardized to Swift 6.3 / Xcode 26.5; added SwiftFormat, SPDX headers, and Apache
  license attribution.

### Fixed
- A store built from an observed store (a projection, a buffer, a feature's view store) no longer records a
  whole-state dependency on its parent when it follows it — which under Combine turned every change into a
  full redraw, and under Observation made the building body depend on everything.

### Removed
- **Breaking:** the old `ViewStore` class, `TrackedViewStore`, `@Tracked`, `ObservableObjectStore` and
  `asObservableObject()` (see *Stores at a Glance* → "Removed — and what replaced them").
- Dropped the XCFramework release path entirely — the pre-built binary artifacts were broken and
  unused. SwiftRex is distributed via Swift Package Manager only. Removes the `rc-build-xcframework`
  CI job and all XCFramework references from the README and the Installation article.

## [0.8.8] - 2026

- Latest tagged release of the redesigned `@Feature` + state-driven navigation API. See the
  [GitHub releases](https://github.com/SwiftRex/SwiftRex/releases) for the detailed history of the
  0.8.x line.

[Unreleased]: https://github.com/SwiftRex/SwiftRex/compare/v0.8.8...main
[0.8.8]: https://github.com/SwiftRex/SwiftRex/releases/tag/v0.8.8
