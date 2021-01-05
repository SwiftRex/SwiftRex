Adds a cancellation token to an Effect. This will re-wrap the upstream in a new Effect that also holds the cancellation token.

{{markdown: effect-cancellation-token.md}}

- Parameters:
  - token: any hashable you want.
- Returns: a new `Effect` instance, wrapping the upstream of original Effect but also holding the cancellation token.