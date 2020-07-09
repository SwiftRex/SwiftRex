A synchronous side-effect that just wraps a single value to be published before the completion.
It lifts a plain value into an `Effect`.
- Parameters:
  - value: the one and only output to be published, synchronously, before the effect completes.
- Returns: an `Effect` that will publish the given value upon subscription, and then complete, immediately.
