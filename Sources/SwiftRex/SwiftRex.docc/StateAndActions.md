# Modelling State & Actions

How to shape the two value types every SwiftRex feature is built from.

## Overview

A SwiftRex feature is defined by two pure values: a **State** (everything the feature needs to render and decide) and an **Action** (everything that can happen to it). There is no `Action` or `State` protocol to adopt — they are plain Swift types you design. Getting their shape right is most of the work; the ``Reducer`` and ``Behavior`` then almost write themselves.

## State is a value, and the single source of truth

Model state as a **value type** — usually a `struct` of `var` properties, or an `enum` when it's a state machine. It is the one place the feature's truth lives; views derive from it, they don't hold their own copies.

```swift
struct ProfileState: Equatable {
    var name: String = ""
    var age: Int = 0
    var birthday: Date = .distantPast
}
```

### Don't store what you can derive

If a value can be *computed* from other state, compute it — don't store it, or you have to remember to keep it in sync.

```swift
struct ProfileState: Equatable {
    var firstName = ""
    var lastName = ""
    var greeting: String { "Hello, \(firstName) \(lastName)" }   // ✓ derived, not stored
}
```

Heavy-to-recompute values are the exception — cache those deliberately and guard them carefully. For view formatting, keep the derivation in the view's slice (a ``StoreProjection``), so the domain state stays minimal.

### Use enums for state machines

When a value moves through a fixed set of phases, an `enum` makes the illegal states unrepresentable:

```swift
enum Movies: Equatable {
    case neverLoaded
    case loading
    case loaded([Movie])
    case failed(String)
}
```

(The FP library's `Loading` type captures this `idle → loading → loaded/failed` shape generically.) Project into the right case with a `Prism` when lifting — see <doc:Lifting>.

## Actions describe what happened, not what to do

An **Action** is an enum of *events* — "the user tapped save", "the request came back" — not imperative commands. Carry just enough payload, and fold async results into the action so the reducer stays deterministic:

```swift
enum ProfileAction {
    case nameChanged(String)
    case saveTapped
    case saveResponse(Result<Profile, SaveError>)   // the effect loops the outcome back as an action
}
```

Wrapping a failable result in the action (rather than in the ``Effect``) is the idiom — the enum case *is* the transform a bridge's `asEffect()` takes. Effects produce actions; the ``Store`` runs the loop.

### Optics for free with macros

The FP macros generate the optics that lifting uses:

- `@Prisms` on an action (or enum state) generates a `Prism` / key-path per case — `\AppAction.profile`, `AppAction.prism.profile` — so a feature's action narrows into the app's.
- `@Lenses` on a `struct` state generates a `Lens` per field, for focusing `let`/immutable slices when a `WritableKeyPath` won't do.

## Every action carries its origin

When an action is dispatched, SwiftRex wraps it in a ``DispatchedAction`` carrying an ``ActionSource`` — the `file`/`function`/`line` of the call site. Middlewares and loggers see *who* dispatched what, which makes the action log a faithful trace of the app. You never construct these by hand; the framework captures the source at each dispatch and effect-factory call site. Element actions in a collection are addressed by id with ``ElementAction``.

## See Also

- ``Reducer``
- ``Behavior``
- ``ActionSource``
- ``DispatchedAction``
- ``ElementAction``
- <doc:Lifting>
