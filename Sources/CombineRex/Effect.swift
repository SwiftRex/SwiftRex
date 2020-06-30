#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

public protocol EffectOutputProtocol {
    associatedtype Action
    var action: Action { get }
    var dispatcher: ActionSource { get }
}

public enum EffectOutput<Action> {
    case dispatch(Action, from: ActionSource = .here())
}

extension EffectOutput: EffectOutputProtocol {
    public var action: Action {
        switch self {
        case let .dispatch(action, _): return action
        }
    }

    public var dispatcher: ActionSource {
        switch self {
        case let .dispatch(_, dispatcher): return dispatcher
        }
    }
}

/// Effect is a Combine Publisher to be returned by Middlewares so they can dispatch Actions back to a Store.
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
/// only available for publishers that have `Failure == Never`.
///
/// An Effect can be a single-shot sync or async, or a long-lasting one such as a timer. That's why
/// cancellation token is so important. The option `.doNothing` is an `Empty` publisher useful for when the
/// middleware decides that certain conditions don't require any side-effect.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct Effect<OutputAction>: Publisher {
    /// Output action matching middleware's `OutputActionType`
    public typealias Output = EffectOutput<OutputAction>
    /// `Effect` publisher can't fail.
    public typealias Failure = Never

    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a
    /// dictionary where the key is this cancellation token. If another effect with the same cancellation
    /// token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    ///
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the
    /// very unlike scenario where the `EffectMiddleware` itself gets deallocated.
    ///
    /// Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running
    /// effects, that way, the dictionary keeping the effects will cleanup the key with that token.
    public let cancellationToken: AnyHashable?
    private let upstream: AnyPublisher<Output, Failure>

    /// Create an effect with any upstream as long as it can't fail. Don't use eager publishers as upstream,
    /// such as Future, as they will unexpectedly start the side-effect before the subscription.
    /// - Parameter upstream: an upstream Publisher that can't fail and should not be eager.
    public init<P: Publisher>(upstream: P) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = nil
    }

    /// Create an effect with any upstream as long as it can't fail. Don't use eager publishers as upstream,
    /// such as Future, as they will unexpectedly start the side-effect before the subscription.
    /// - Parameters:
    ///   - upstream: an upstream Publisher that can't fail and should not be eager.
    ///   - cancellationToken: Cancellation token is any hashable used later to eventually cancel this effect
    ///                        before its completion. Once this effect is subscribed to, the subscription (in
    ///                        form of `AnyCancellable`) will be kept in a dictionary where the key is this
    ///                        cancellation token. If another effect with the same cancellation token arrives,
    ///                        the former will be immediately replaced in the dictionary and, therefore,
    ///                        cancelled. If you don't want this, not providing a cancellation token will only
    ///                        cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself
    ///                        gets deallocated. Cancellation tokens can also be provided to the
    ///                        `EffectMiddleware` to force cancellation of running effects, that way, the
    ///                        dictionary keeping the effects will cleanup the key with that token.
    public init<P: Publisher, H: Hashable>(upstream: P, cancellationToken: H) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = cancellationToken
    }

    /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
    ///
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///     - subscriber: The subscriber to attach to this `Publisher`.
    ///                   once attached it can begin to receive values.
    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        upstream.subscribe(subscriber)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
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

    /// An Empty effect that will complete immediately without emitting any output. Useful for when the Middleware
    /// doesn't want to perform any side-effect.
    public static var doNothing: Effect {
        Empty().asEffect(dispatcher: .here())
    }

    /// A synchronous side-effect that just wraps a single value to be published before the completion.
    /// It lifts a plain value into an `Effect`.
    /// - Parameter value: the one and only output to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given value upon subscription, and then complete, immediately.
    public static func just(_ value: OutputAction, from dispatcher: ActionSource = .here()) -> Effect {
        Just(value).asEffect(dispatcher: dispatcher)
    }

    /// A synchronous side-effect that just wraps a sequence of values to be published before the completion.
    /// It lifts a plain sequence of values into an `Effect`.
    /// - Parameter values: the sequence of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: OutputAction..., from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
    }

    /// A synchronous side-effect that just wraps an Array of values to be published before the completion.
    /// It lifts a plain Array of values into an `Effect`.
    /// - Parameter values: the Array of output values to be published, synchronously, before the effect completes.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: [OutputAction], from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
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
    public static func promise(_ operation: @escaping ((Output) -> Void) -> Void) -> Effect {
        Deferred {
            Future { completion in
                operation { callback in
                    completion(.success(callback))
                }
            }
        }.asEffect
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    public static func merge(_ a: Effect, _ b: Effect) -> Effect {
        a.merge(with: b).asEffect
    }

    public static func merge(_ a: Effect, _ b: Effect, _ c: Effect) -> Effect {
        a.merge(with: b).merge(with: c).asEffect
    }

    public static func merge(_ a: Effect, _ b: Effect, _ c: Effect, _ d: Effect) -> Effect {
        a.merge(with: b, c, d).asEffect
    }

    public static func merge(_ a: Effect, _ b: Effect, _ c: Effect, _ d: Effect, _ e: Effect) -> Effect {
        a.merge(with: b, c, d, e).asEffect
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Failure == Never {
    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already
    /// happening before the subscription.
    public func asEffect(dispatcher: ActionSource) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher) })
    }

    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already
    /// happening before the subscription. Also contains a cancellation token.
    ///
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion.
    /// Once this effect is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a
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
    /// - Returns: an `Effect` wrapping this Publisher as its upstream, plus a cancellation token.
    public func asEffect<H: Hashable>(dispatcher: ActionSource, cancellationToken: H) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher)}, cancellationToken: cancellationToken)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Output: EffectOutputProtocol, Failure == Never {
    public var asEffect: Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) })
    }

    public func asEffect<H: Hashable>(cancellationToken: H) -> Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) },
                                   cancellationToken: cancellationToken)
    }
}
#endif
