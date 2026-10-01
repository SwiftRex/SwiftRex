# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

A ground-up rewrite. Nothing below shipped in 0.8.x; the 0.8.x API (`CombineRex`, `RxSwiftRex`,
`ReactiveSwiftRex`, `ReduxStoreBase`, `Middleware` protocols with `handle(action:from:state:)`, the old view
stores) does not carry over — see the DocC catalog and *Migrating to ViewStore and StateStream* for the new
model. Swift 6.3, strict concurrency, `@MainActor` store; macOS 13 / iOS 16 / tvOS 16 / watchOS 9, and the
core and every non-Apple product build on Linux.

### Core (`SwiftRex`)
- **Values, not objects.** `Reducer`, `Middleware` and `Behavior` (reducer + effects + supervision in one value)
  are pure, composable monoids; effects are inert `Effect` values the `Store` alone runs. `Consequence`
  (`Reaction` = reduce/produce, `Supervision` = keep) names what a behavior returns.
- **`Store`** — the one owner of state and the only thing that executes. `StoreType` is
  `dispatch(_:source:)` + `stateStream`: a store has no readable `state`; it is followed, not read.
- **`StateStream<State>`** — state over time, main-actor: current value first, synchronously, then every change,
  in the same run loop as the dispatch (`withAnimation` holds end to end). `map`, `removeDuplicates`,
  `AsyncSequence`; `UISubscriptionToken` cancels synchronously.
- **Pure stages** between stores, keeping nothing a parent holds: `StoreProjection` (a map), `StoreBuffer`
  (per-subscriber `removeDuplicates`), `StoreCollectionFocus` (one element of a collection — by id, custom id,
  position or key — found through a per-observer hint, O(distance moved)), `StoreOptionalFocus` (a store of `T`
  over `T?`, holding the last present value), `IdentifiedStore` (a store with an id, for lists).
- **`Relay.Scope`** — one value describing how a child's `(Action, State, Environment)` sits in a parent's, used by
  every host: `lift`, `liftOptional`, `liftCollection`, `liftEach`, `projection`, `.on(…, dispatch:…)`, and in SwiftUI
  `binding`, `traverse`, `each`, `liftPresentation`, `.view(of:from:world:)`. Inline (`.action(\.x).state(\.x)
  .environment(…)`) or declared once (`static let x = ScopeOf<AppFeature>.action(\.x)…`). Lanes take `\.case`
  key paths, prisms, key paths, lenses, affine traversals or closures; a state lane can focus an enum case
  (`.state(\.loaded)`).
- **Effects:** scheduling (`replacing`, `cancelInFlight`, throttle, debounce, delays on an injected clock),
  long-lived `Channel`s, state-driven supervision, per-element effect scoping in collection lifts.
- `ElementAction`, `Rig` / `Transceiver`, an injectable `Clock`, `ActionSource` on every dispatch.

### Bridges
- `SwiftRex.SwiftConcurrency`, `SwiftRex.Combine`, `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`,
  `SwiftRex.ReactiveConcurrency` (the last three behind package traits): effects and channels from each runtime,
  and `StateStream` as that runtime's own type (a Combine `Publisher`, an `ObservableType`, a
  `SignalProducerConvertible`, `asPublisher`) — current state first, delivered on the main actor.

### SwiftUI (`SwiftRex.SwiftUI`)
- **`ViewStore`** — the only readable store and the only leaf with a snapshot and observation. Made explicitly,
  from any store: `store.viewStore()` / `.viewStore(.combine)`; kept by `@OwnedStore` in the view that uses it;
  handed down as a plain `let`. A view store forwards the upstream values it receives to the stages derived from
  it.
- **Granular reads** at any depth: `viewStore.state.x` records exactly the key paths a view reads
  (`GranularTracking` positions, `IndivisibleTracking` values, `each(\.rows)` for lists, `read(derived:)`), and only
  the views that read a changed path redraw — through Observation on iOS 17+ or a dependency-aware Combine signal
  below (`ViewStrategy.automatic` / `.observation` / `.combine`).
- **Children as pure stages:** `projection(scope)` for a slice, `transpose()` for the view store's own optional,
  `traverse(scope)` (map, then transpose) for an optional or `Presentation` slot or one element, `each(scope)` for
  rows that dispatch. Presence is read as an edge; a child holds its last value while it animates away.
- **Bindings:** one `binding(.state(…).action(…))`; the action lane decides two-way, dismiss-only or
  presentation. An `Equatable` two-way binding drops a write equal to the current value.
- **Navigation:** `Presentation<T>` + `PresentationAction` (`.dismiss` when a dismissal starts, `.dismissed` when it
  ends, `@Prisms`) and `liftPresentation`; `Routable` routers; `hasScene` for multi-window apps.

### Architecture (`SwiftRex.Architecture`)
- `@Feature` turns an `enum` namespace into a feature (optics, `initialState(with:)`, the `Feature` conformance and a
  `view(store:environment:)` whose generated `FeatureRoot` keeps its view store); `@BoundTo` injects the view's
  `let viewStore`. `HasBehavior` / `ViewFactory` / `Feature`; `Relay.Scope` builds a child's behavior
  (`.behavior(of:)`) and view (`.view(of:from:world:)`, for total, optional and `Presentation` slots).
- Navigation reducers: `navigationStack`, `navigationItem`, `navigationSelection` over `@Prisms`
  `StackNavigation`, `ModalNavigation`, `SelectionNavigation`.

### Testing (`SwiftRex.Testing`)
- `TestStore`: exhaustive `dispatch(_:assert:)` / `receive`, effects run through the production effect engine
  (scheduling and channels included), an injectable test clock.

### Packaging
- Products renamed to `SwiftRex`, `SwiftRex.Operators`, `SwiftRex.SwiftConcurrency`, `SwiftRex.Combine`,
  `SwiftRex.RxSwift`, `SwiftRex.ReactiveSwift`, `SwiftRex.ReactiveConcurrency`, `SwiftRex.SwiftUI`,
  `SwiftRex.Architecture`, `SwiftRex.Testing`; the dynamic-library products and the XCFramework release path are
  gone (Swift Package Manager only).
- Depends on FP 2.2.0, Hourglass 1.0.1, ReactiveConcurrency 1.1.0 (trait), RxSwift 6.10 / ReactiveSwift 7.2
  (traits), swift-syntax 603.

## [0.8.12] - 2022-04-02

- Last release of the original architecture (`CombineRex`, `RxSwiftRex`, `ReactiveSwiftRex`). See the
  [GitHub releases](https://github.com/SwiftRex/SwiftRex/releases) for the history of the 0.8.x line.

[Unreleased]: https://github.com/SwiftRex/SwiftRex/compare/0.8.12...main
[0.8.12]: https://github.com/SwiftRex/SwiftRex/releases/tag/0.8.12
