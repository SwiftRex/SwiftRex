Create an effect with any upstream as long as it can't fail. Don't use eager publishers as upstream, such as Future, as they will unexpectedly start the side-effect before the subscription.
- Parameters:
  - upstream: an upstream Publisher that can't fail and should not be eager.
  - cancellationToken: {{markdown: effect-cancellation-token.md}}