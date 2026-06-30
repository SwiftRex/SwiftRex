# The Algebra

Why SwiftRex is a handful of monoids and a single interpreter — and what that buys you.

## Overview

SwiftRex's core types form a small, lawful algebra. There is really only one way to put things together — a **monoid** — and only one thing that ever runs — the ``Store``. Once those two ideas click, the rest of the library is a consequence.

## Everything composes the same way: monoids

A **monoid** is a type with a `combine` that takes two values and returns one of the same type, plus an `identity` value that changes nothing when combined. That's it. SwiftRex leans on it everywhere, so "wire two features together" is always the same move — `combine` — and never bespoke glue.

| Type | What `combine` means | `identity` |
|---|---|---|
| ``Reducer`` | **sequential** — run `lhs` then `rhs` on the same `inout State`; order matters, `rhs` sees `lhs`'s change | a reducer that mutates nothing |
| ``Effect`` | **parallel** — both run; the ``Store`` interprets them concurrently | `.empty` |
| ``ReducerOutcome`` | absorb ``ReducerOutcome/unchanged``; otherwise compose the underlying `EndoMut` mutations | `.unchanged` |
| ``Reaction`` | **product** — componentwise: the ``ReducerOutcome`` (sequential) × the effect `Reader` (parallel) | `.doNothing` |
| ``Supervision`` | the channels to ``Keep`` for a state; sets **union** | a reader to `[]` |
| ``Behavior`` | the **free monoid** `[Consequence]`; concatenation | `.identity` (`[]`) |
| ``Middleware`` | the effect-only ``Behavior`` (`produce` + `supervise`) | `.identity` |

Two keystones. ``Reaction`` is a **product monoid** — the action-clock half of a ``Consequence``: the pair of *what state change to apply* (a ``ReducerOutcome``) and *what effect to perform afterward* (a `Reader<PostReducerContext, Effect>`). ``Behavior`` is the **free monoid** `[Consequence]`: each consequence is a ``reaction`` (action clock) or a ``supervision`` (state clock), and combining features just concatenates their lists. Reactions fold (mutations **sequential**, effects **parallel**), supervisions **union** — and you still hold a single value.

### Describe, don't do

The left of each pair is a pure description; the ``Store`` is the only thing that acts. `reduce` describes a mutation → the Store **mutates**; `produce` describes an effect → the Store **performs**; `supervise` describes channels → the Store **keeps** them. Building a ``Behavior`` runs nothing.

```swift
// Two independent features, composed with the monoid:
let app = counter.lifted <> profile.lifted        // <> is `combine`
// `app` is one Behavior; dispatching an action runs both, atomically.
```

## Only the Store runs: it's an IO runtime

A ``Reducer``, an ``Effect``, a ``Behavior`` are *descriptions*. Building one executes nothing — no task starts, no state changes. The ``Store`` is the sole **interpreter** (think Haskell's `IO` at the program's edge): it's the one place effects fire and state mutates.

For each action, on the main actor, the Store runs three phases:

1. **Pre-mutation.** `behavior.handle(action, preContext)` folds the action-clock reactions into one ``Reaction``. The ``PreReducerContext`` exposes the *current* state.
2. **Mutation (zero-copy).** If the outcome is ``ReducerOutcome/unchanged``, nothing happens and **no observer is notified**. Otherwise: `willChange` → the `EndoMut` mutates `state` in place → `didChange`.
3. **Effects.** A ``PostReducerContext`` (now exposing *post-mutation* state and the `Environment`) resolves the effect `Reader`; each ``Effect`` component is scheduled by its ``EffectScheduling`` (``EffectScheduling/immediately``, `.replacing`, `.debounce`, `.throttle`, `.cancelInFlight`). Actions produced by effects loop back to phase 1.

## What the algebra guarantees

The monoid-plus-one-interpreter design isn't aesthetic — it's where the runtime guarantees come from:

- **Exactly one notification per state-changing action.** A composed ``Behavior`` runs *all* its parts inside a single `handle` call; by Swift's Law of Exclusivity the Store regains `state` only after the whole pipeline finishes — observers never see a half-applied state. Pure-routing or effect-only actions resolve to ``ReducerOutcome/unchanged`` and notify **zero** times.
- **Zero-copy mutation.** State changes through `inout` / `EndoMut`, never a copy-to-diff.
- **Effects see committed state.** Effect closures resolve against post-mutation state, via ``PostReducerContext``.
- **Re-entrancy is safe.** Actions dispatched while the Store is mid-drain are queued and processed FIFO; a runaway loop is cut off at ``StoreHooks/reentranceThreshold``.

## The view boundary stays pure too

The ``Store`` never deduplicates — it always notifies, copies nothing. Narrowing for views is done by two pure helpers:

- ``StoreProjection`` — a *stateless* `struct` that maps global action/state to a local slice (a lens with no storage of its own).
- ``StoreBuffer`` — the caching/deduplicating layer that skips propagation when the projected slice is unchanged (`Equatable`, or a custom predicate).

## See also

- ``Behavior``
- ``Consequence``
- ``Reaction``
- ``Store``
- ``Reducer``
- ``Effect``
