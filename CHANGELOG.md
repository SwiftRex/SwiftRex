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
  for list rows), `IndivisibleTracking` (types read whole), owners `@OwnedStore` and `ProjectionKeeper`.
- **Pure until the leaf.** Composition is pure stages — `StoreProjection`, `StoreBuffer`, and new `StoreCollectionFocus`
  (one element of a collection, by id, position or key; each observer keeps a hint, O(distance moved)) and
  `StoreOptionalFocus` (a store of `T` over `T?`, holding the last present value). The `ViewStore` is the only leaf: it
  owns a snapshot and the observation work, always has one owner, and whatever is derived from it is a pure stage
  built on its pure side (its `stateStream` is the upstream chain, never the snapshot).
- `ViewStrategy.automatic` (default): Observation on iOS 17+, Combine below, decided at runtime.
- `read(derived:)` — depend on a computed value instead of the whole state.
- `transpose` — `F<T?>` into `F<T>?`, depending on the presence edge only. On a `ViewStore`: its own optional or
  `Presentation` state, a scope's slot (`transpose(.action(\.x).state(\.x))`), a collection element
  (`transpose(scope, element: id)`) or a closure lane (`transpose(action:state:)`) — each returns a `StoreOptionalFocus`
  for the child to own. On a position, `GranularTracking<T?>` → `GranularTracking<T>?`. Both hold the last present
  value while the value is going away.
- One `binding` taking a chained scope, `binding(.state(…).action(…))`; what the action lane embeds decides the
  kind: the value (two-way `Binding<T>`), a no-payload case on an optional slot (dismiss-only `Binding<Bool>` /
  `Binding<T?>`, typed by the SwiftUI parameter), or a `PresentationAction` on a `Presentation` slot
  (`Binding<Presentation<T>>` carrying both dismissal edges — `.sheet(item:)` takes it directly;
  `.isPresented()`, `.item()` and `.onDismiss()` feed any other container).
- `PresentationAction` gets the full `@Prisms` surface (`\.editor.child` reaches the presented child's lane).
- A `ViewStore` is made explicitly, from any store: `store.viewStore()` / `store.viewStore(.combine)` (existentials
  included). `@OwnedStore` and `ProjectionKeeper` only keep the `ViewStore` they're given — no strategy argument,
  no upstream-taking initialiser: `@OwnedStore var viewStore = store.viewStore()`.
- A two-way `binding` over an `Equatable` value drops a write equal to the current value — SwiftUI can write a
  binding twice for one gesture, which dispatched the action twice.
- `ForEach(viewStore.state.items)` now fails with a message naming the fix (`each(\.items)`, or `.value`) instead of
  an unrelated `IndivisibleTracking` requirement.
- Article: *Migrating to ViewStore and StateStream* — ordered, mechanical steps, rewrite rules, compiler
  symptoms, and pitfalls.
- Articles: *Stores at a Glance*, *Observing a Store in SwiftUI*.

### Changed
- **Breaking:** `StoreType` is `dispatch(_:source:)` + `stateStream`. There is no `state` on a store (a
  `Store`'s is private; `TestStore.state` stays) and no `observe(willChange:didChange:)` — a store is
  followed, not read; views read through a `ViewStore`. `StoreBuffer` is a struct with no shared cache.
- **Breaking:** bindings live on `ViewStore` only — they no longer compile on a raw `Store` or
  `StoreProjection`, which SwiftUI can't observe. `presence`, `item`, `presenting` and `presentingItem` are
  gone (one `binding`, above); `binding` takes one chained scope, like `projection`; there is no `focus` — children are derived (`projection`,
  `transpose`) and owned.
- **Breaking:** `PresentationAction` has two dismissal cases: `.dismiss` when a dismissal starts
  (`presented → dismissing`) and `.dismissed` when SwiftUI's animation ends (`→ dismissed`).
  `Presentation.dismiss()` only starts a dismissal.
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
  `asObservableObject()`, `store.publisher`, `store.stream`, the core `StoreType.transpose()`, `unwrapped()` and `peek` in
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
