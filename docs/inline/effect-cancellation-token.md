Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.

If you don't want this, not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets deallocated.

Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the dictionary keeping the effects will cleanup the key with that token.
