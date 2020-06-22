import Foundation
import ReactiveSwift

/// Effect is a Signal Producer to be returned by Middlewares so they can dispatch Actions back to a Store.
/// Every effect will have a cancellation token to be later cancelled by new action arrivals, such as in the
/// case when the user is no longer interested in certain HTTP Request or wants to stop a timer. When
/// cancellation token is not provided during the initialization of an Effect, it still can be passed later,
/// which will rewrap the upstream again in a new Effect, but this time containing the cancellation token.
/// Some static constructors are available, such as `.doNothing`, `.just(_: Output)`, `.sequence(_: Output...)`,
/// `.sequence(_: [Output]`, `.promise(_: CompletionHandler)`, etc.
///
/// An Effect can never Fail, so any possible failure of its upstream must be caught and treated before the
/// Effect is created. For example, if you have an effect that uses URLSession to fetch some data from an URL,
/// once you get your data back you can dispatch a successful action. But in case the task returns an URLError
/// or some unexpected URLResponse, you should not fail, but instead, replace the error with an action to be
/// dispatched telling your store that the request has failed. This will enforce the usage of Actions as
/// communication units between different middlewares and reducers.
///
/// That's also the reason why `.asEffect` and `.asEffect<H: Hashable>(cancellationToken: H)` extensions are
/// only available for `SignalProducers` that have `Error == Never`.
///
/// An Effect can be a single-shot sync or async, or a long-lasting one such as a timer. That's why
/// cancellation token is so important. The option `.doNothing` is an `.empty` `SignalProducer` useful for when
/// the middleware decides that certain conditions don't require any side-effect.
public struct Effect<OutputAction>: SignalProducerProtocol {
    /// Output action matching middleware's `OutputActionType`
    public typealias Value = OutputAction
    /// `Effect` SignalProducer can't fail.
    public typealias Error = Never

    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `Lifetime.Token`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the `EffectMiddleware` itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    public let cancellationToken: AnyHashable?
    private let upstream: SignalProducer<Value, Never>

    /// Create an effect with any upstream as long as it can't fail.
    /// - Parameter upstream: an upstream SignalProducerProtocol that can't fail.
    public init<P: SignalProducerProtocol>(upstream: P) where P.Value == Value, P.Error == Never {
        self.upstream = upstream.producer
        self.cancellationToken = nil
    }

    /// Create an effect with any upstream as long as it can't fail.
    /// - Parameters:
    ///   - upstream: an upstream `SignalProducer` that can't fail.
    ///   - cancellationToken: Cancellation token is any hashable used later to eventually cancel this effect
    ///                        before its completion. Once this effect is subscribed to, the subscription (in
    ///                        form of `Lifetime.Token`) will be kept in a dictionary where the key is this
    ///                        cancellation token. If another effect with the same cancellation token arrives,
    ///                        the former will be immediately replaced in the dictionary and, therefore,
    ///                        cancelled. If you don't want this, not providing a cancellation token will only
    ///                        cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself
    ///                        gets deallocated. Cancellation tokens can also be provided to the
    ///                        `EffectMiddleware` to force cancellation of running effects, that way, the
    ///                        dictionary keeping the effects will cleanup the key with that token.
    public init<P: SignalProducerProtocol, H: Hashable>(upstream: P, cancellationToken: H)
    where P.Value == Value, P.Error == Never {
        self.upstream = upstream.producer
        self.cancellationToken = cancellationToken
    }

    public var producer: SignalProducer<Value, Never> { upstream }
}

extension Effect {
    /// Adds a cancellation token to an Effect. This will rewrap the upstream in a new Effect that also holds the
    /// cancellation token.
    ///
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `Lifetime.Token`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the `EffectMiddleware` itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    ///
    /// - Parameter token: any hashable you want.
    /// - Returns: a new `Effect` instance, wrapping the upstream of original Effect but also holding the
    ///            cancellation token.
    public func cancellation<H: Hashable>(token: H) -> Effect {
        Effect(upstream: self.upstream, cancellationToken: token)
    }

    /// A `SignalProducer.empty` effect that will complete immediately without emitting any output. Useful for when
    /// the Middleware doesn't want to perform any side-effect.
    public static var doNothing: Effect {
        SignalProducer.empty.asEffect
    }

    /// A synchronous side-effect that just wraps a single value to be published before the completion.
    /// It lifts a plain value into an `Effect`.
    /// - Parameter value: the one and only output to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given value upon subscription, and then complete, immediately.
    public static func just(_ value: Value) -> Effect {
        SignalProducer(value: value).asEffect
    }

    /// A synchronous side-effect that just wraps a sequence of values to be published before the completion.
    /// It lifts a plain sequence of values into an `Effect`.
    /// - Parameter values: the sequence of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: Value...) -> Effect {
        SignalProducer(values).asEffect
    }

    /// A synchronous side-effect that just wraps an Array of values to be published before the completion.
    /// It lifts a plain Array of values into an `Effect`.
    /// - Parameter values: the Array of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: [Value]) -> Effect {
        SignalProducer(values).asEffect
    }

    /// An async task that will start upon subscription and needs to call a completion handler once when it's done.
    /// You can create an Effect promise like this:
    /// ```
    /// Effect<String>.promise { completion in
    ///     let task = doSomethingAsync { outputString in
    ///         completion(outputString)
    ///     }
    ///     return AnyDisposable() // Or a way to cancel the ongoing task
    /// }
    /// ```
    ///
    /// - Parameter operation: a closure that gives you a completion handler to be called once the async task is
    ///                        done, and returns a Disposable object that can be used for cancellation purposes
    /// - Returns: an `Effect` that will eventually publish the given output when you call the completion handler.
    ///            and that will only call your async task once it's subscribed by the Effect Middleware. Then, it
    ///            will complete immediately as soon as it emits the first value.
    public static func promise(_ operation: @escaping ((Value) -> Void) -> Disposable) -> Effect {
        SignalProducer<Value, Never> { observer, lifetime in
            lifetime += operation { value in
                observer.send(value: value)
                observer.sendCompleted()
            }
        }.asEffect
    }
}

extension SignalProducerProtocol where Error == Never {
    /// Erases any unfailable `SignalProducer` to effect.
    public var asEffect: Effect<Value> {
        Effect(upstream: self)
    }

    /// Erases any unfailable `SignalProducer` to effect. Also contains a cancellation token.
    ///
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `Lifetime.Token`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the `EffectMiddleware` itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    ///
    /// - Parameter cancellationToken: cancellation token for this effect, as explained in the method
    ///                                description
    /// - Returns: an `Effect` wrapping this `SignalProducer` as its upstream, plus a cancellation token.
    public func asEffect<H: Hashable>(cancellationToken: H) -> Effect<Value> {
        Effect(upstream: self, cancellationToken: cancellationToken)
    }
}
