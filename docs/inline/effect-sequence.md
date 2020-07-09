A synchronous side-effect that just wraps a sequence of values to be published before the completion.
It lifts a plain sequence of values into an `Effect`.
- Parameters:
  - values: the sequence of output values to be published, synchronously, before the effect completes.
- Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.