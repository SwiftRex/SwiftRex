import Foundation
import RxSwift

/// Effect is a RxSwift Observable to be returned by Middlewares so they can dispatch Actions back to a Store.
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
/// That's also the reason why `.asEffect` and `.asEffect<H: Hashable>(cancellationToken: H)` extensions should
/// only be used on observables that won't fail.
///
/// An Effect can be a single-shot sync or async, or a long-lasting one such as a timer. That's why
/// cancellation token is so important. The option `.doNothing` is an `.empty()` observable useful for when the
/// middleware decides that certain conditions don't require any side-effect.
public struct Effect<OutputAction>: ObservableType {
    /// Element action matching middleware's `OutputActionType`
    public typealias Element = OutputAction

    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `Disposable`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately disposed and replaced in the dictionary.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the EffectMiddleware itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the EffectMiddleware to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    public let cancellationToken: AnyHashable?
    private let upstream: Observable<Element>

    /// Create an effect with any upstream as long as it can't fail. Don't use eager observables as upstream,
    /// such as Future, as they will unexpectedly start the side-effect before the subscription.
    /// - Parameter upstream: an upstream Observable that can't fail and should not be eager.
    public init<P: ObservableType>(upstream: P) where P.Element == Element {
        self.upstream = upstream.asObservable()
        self.cancellationToken = nil
    }

    /// Create an effect with any upstream as long as it can't fail. Don't use eager observables as upstream,
    /// such as Future, as they will unexpectedly start the side-effect before the subscription.
    /// - Parameters:
    ///   - upstream: an upstream Observable that can't fail and should not be eager.
    ///   - cancellationToken: Cancellation token is any hashable used later to eventually cancel this effect
    ///                        before its completion. Once this effect is subscribed to, the subscription (in
    ///                        form of `AnyCancellable`) will be kept in a dictionary where the key is this
    ///                        cancellation token. If another effect with the same cancellation token arrives,
    ///                        the former will be immediately replaced in the dictionary and, therefore,
    ///                        cancelled. If you don't want this, not providing a cancellation token will only
    ///                        cancel your Effect in the very unlike scenario where the EffectMiddleware itself
    ///                        gets deallocated. Cancellation tokens can also be provided to the
    ///                        EffectMiddleware to force cancellation of running effects, that way, the
    ///                        dictionary keeping the effects will cleanup the key with that token.
    public init<P: ObservableType, H: Hashable>(upstream: P, cancellationToken: H)
    where P.Element == Element {
        self.upstream = upstream.asObservable()
        self.cancellationToken = cancellationToken
    }

    /// Subscribes `observer` to receive events for this sequence.
    ///
    /// - Parameter observer: the counterpart willing to observe this observable for events and completion.
    /// - Returns: Subscription for `observer` that can be used to cancel production of sequence elements and free resources.
    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable
    where Element == Observer.Element {
        upstream.subscribe(observer)
    }
}

extension Effect {
    /// Adds a cancellation token to an Effect. This will rewrap the upstream in a new Effect that also holds the
    /// cancellation token.
    ///
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the EffectMiddleware itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the EffectMiddleware to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    ///
    /// - Parameter token: any hashable you want.
    /// - Returns: a new `Effect` instance, wrapping the upstream of original Effect but also holding the
    ///            cancellation token.
    public func cancellation<H: Hashable>(token: H) -> Effect {
        Effect(upstream: self.upstream, cancellationToken: token)
    }

    /// An Empty effect that will complete immediately without emitting any output. Useful for when the Middleware
    /// doesn't want to perform any side-effect.
    public static var doNothing: Effect {
        Observable.empty().asEffect
    }

    /// A synchronous side-effect that just wraps a single value to be published before the completion.
    /// It lifts a plain value into an `Effect`.
    /// - Parameter value: the one and only output to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given value upon subscription, and then complete, immediately.
    public static func just(_ value: Element) -> Effect {
        Observable.just(value).asEffect
    }

    /// A synchronous side-effect that just wraps a sequence of values to be published before the completion.
    /// It lifts a plain sequence of values into an `Effect`.
    /// - Parameter values: the sequence of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: Element...) -> Effect {
        Observable.from(values).asEffect
    }

    /// A synchronous side-effect that just wraps an Array of values to be published before the completion.
    /// It lifts a plain Array of values into an `Effect`.
    /// - Parameter values: the Array of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: [Element]) -> Effect {
        Observable.from(values).asEffect
    }

    /// An async task that will start upon subscription and needs to call a completion handler once when it's done.
    /// You can create an Effect promise like this:
    /// ```
    /// Effect<String>.promise { completion in
    ///     doSomethingAsync { outputString in
    ///         completion(outputString)
    ///     }
    /// }
    /// ```
    /// Internally creates a `Deferred<Future<Output, Never>>`
    ///
    /// - Parameter operation: a closure that gives you a completion handler to be called once the async task is
    ///                        done
    /// - Returns: an `Effect` that will eventually publish the given output when you call the completion handler.
    ///            and that will only call your async task once it's subscribed by the Effect Middleware. Then, it
    ///            will complete immediately as soon as it emits the first value.
    public static func promise(_ operation: @escaping ((Element) -> Void) -> Disposable) -> Effect {
        Observable.create { observer -> Disposable in
            operation { value in
                observer.onNext(value)
                observer.onCompleted()
            }
        }.asEffect
    }
}

extension ObservableType {

    /// Erases any unfailable Observable to effect. Don't call this on eager Observables or the effect is already
    /// happening before the subscription.
    public var asEffect: Effect<Element> {
        Effect(upstream: self)
    }

    /// Erases any unfailable Observable to effect. Don't call this on eager Observables or the effect is already
    /// happening before the subscription. Also contains a cancellation token.
    ///
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the EffectMiddleware itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the EffectMiddleware to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    ///
    /// - Parameter cancellationToken: cancellation token for this effect, as explained in the method
    ///                                description
    /// - Returns: an `Effect` wrapping this Observable as its upstream, plus a cancellation token.
    public func asEffect<H: Hashable>(cancellationToken: H) -> Effect<Element> {
        Effect(upstream: self, cancellationToken: cancellationToken)
    }
}
