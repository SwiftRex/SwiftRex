# Example: Polling an API

Re-fetch on an interval while a query is set — and restart cleanly the moment the query changes.

## Overview

Polling is a timer with a payload: while there's something to poll *for*, keep asking and fold each answer back in as an action. The query lives in state, so the poll's lifetime — and its identity — are functions of state.

```swift
import SwiftRex

struct Hit: Sendable, Equatable { … }

struct SearchEnv: Sendable {
    let search: @Sendable (String) async -> [Hit]
    let clock: any Clock<Duration>
}

enum SearchAction: Sendable {
    case setQuery(String)
    case results([Hit])
}

struct SearchState: Sendable {
    var query = ""
    var hits: [Hit] = []
}

let search = Behavior<SearchAction, SearchState, SearchEnv>
    .reduce { action, state in
        switch action {
        case .setQuery(let q): state.query = q
        case .results(let hits): state.hits = hits
        }
    }
    .supervise { state in
        Keep { env in
            guard !state.query.isEmpty else { return [] }       // no query → no poll
            let query = state.query
            return [Channel(id: "poll", lifetime: .ephemeral(resetKey: query)) { dispatch in
                let task = Task {
                    while !Task.isCancelled {
                        dispatch(.results(await env.search(query)))
                        try? await env.clock.sleep(for: .seconds(5))
                    }
                }
                return .cancelOnly { task.cancel() }
            }]
        }
    }
```

### What each piece does

- **`Keep { env in … }` reads dependencies** — `supervise` returns a ``Keep``, a `Reader` from the environment to the channels. `env.search` and `env.clock` are injected by the ``Store``, so the feature stays pure and the poll is trivially testable with a stub `search` and a `TestClock`.
- **`.ephemeral(resetKey: query)`** — change the query and the channel *recreates*: the in-flight poll for the old query is cancelled and a fresh one starts for the new one. No debounce bookkeeping, no "is this response stale?" check — a different `resetKey` is a different resource.
- **Empty query cancels it** — `guard !state.query.isEmpty` returns `[]`, so clearing the field tears the poll down. The teardown is *not having a query*, never a `.stopPolling` action.
- **Results loop back as actions** — `dispatch(.results(…))` re-enters the Store through the normal path, so the reducer (and any other feature) sees the new hits exactly like any user action.

### Contrast with `react`

You *could* fetch from a `react` on `.setQuery` — a one-shot `react` returning `Effect.throwingTask` (from `SwiftRex.SwiftConcurrency`). That's right for a **single** fetch. The moment you want it to *repeat while the query holds*, it's a subscription — `supervise` owns the loop and the lifetime, and you delete the manual restart logic.

## See Also

- <doc:StateDrivenEffects>
- <doc:Channels>
- <doc:ExampleTimer>
- <doc:AddingEffects>
- ``Keep``
