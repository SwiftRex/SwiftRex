Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already happening before the subscription.

An optional cancellation token can be provided to avoid duplicated effect of the same time, or for manual cancellation at any point later.

{{markdown: effect-cancellation-token.md}}

If the Publisher outputs some `EffectOutput<OutputAction>` events, then the action source (dispatcher) is already known, it's the line that created the EffectOutput instance. However, if the upstream Publisher outputs only `OutputAction`, then a `dispatcher: ActionSource` must also be provided so the Store knows where this action is coming from. In that case you can provide `ActionSource.here()` if this line of code is to be referred as the source.

- Parameters:
  - dispatcher: the action source, so the Store and other middlewares know where this action is coming from. You can provide `ActionSource.here()` if this line of code is to be referred as the source. A better way is to set the upstream Publisher Output Type as `EffectOutput<OutputAction>`, not `OutputAction`, so once you create the `EffectOutput` is set as the action source, providing a better logging results for you.
  - cancellationToken: cancellation token for this effect, as explained in the method description
- Returns: an `Effect` wrapping this Publisher as its upstream.