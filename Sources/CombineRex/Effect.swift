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

extension EffectOutput {
    public func map<NewAction>(_ transform: (Action) -> NewAction) -> EffectOutput<NewAction> {
        switch self {
        case let .dispatch(action, dispatcher):
            return .dispatch(transform(action), from: dispatcher)
        }
    }
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

// markdown: effect.md
/// `Effect` is a Publisher/Observable/SignalProducer to be returned by Middlewares so they can dispatch Actions back to a Store. Every effect may 
/// have a cancellation token to be later cancelled by new action arrivals, such as in the case when the user is no longer interested in certain HTTP 
/// Request or wants to stop a timer. When cancellation token is not provided during the initialization of an Effect, it still can be passed later, 
/// which will re-wrap the upstream again in a new Effect, but this time containing the cancellation token. Some static constructors are available, 
/// such as `.doNothing`, `.just(_: Output)`, `.sequence(_: Output...)`, `.sequence(_: [Output]`, `.promise(_: CompletionHandler)`, etc.
/// 
/// `Effect` is a stream of the type `EffectOutput`, which contains the action and the action source. Most of the times you want to create the 
/// `EffectOutput` by simply calling `EffectOutput.dispatch(myAction)`, where myAction matches the `OutputActionType` of this middleware.
/// 
/// An Effect should never Fail, so any possible failure of its upstream must be caught and treated before the Effect is created. For example, if you 
/// have an upstream that uses URLSession to fetch some data from an URL, once you get your data back you can dispatch a successful action. But in 
/// case the task returns an URLError or some unexpected URLResponse, you should not fail, but instead, replace the error with an action to be 
/// dispatched telling your store that the request has failed. This will enforce the usage of Actions as communication units between different 
/// middlewares and reducers.
/// 
/// That's also the reason why `.asEffect()`, `.asEffect<H: Hashable>(cancellationToken: H)` and
/// `.asEffect<H: Hashable>(dispatcher: ActionSource, cancellationToken: H)` extensions are only available for publishers that have `Failure == 
/// Never`, when the reactive framework supports Failure constraints.
/// 
/// An Effect can be a single-shot sync or async, or a long-lasting one such as a timer. That's why cancellation token is so important. The option 
/// `.doNothing` is an `Empty` publisher useful for when the middleware decides that certain conditions don't require any side-effect.
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct Effect<OutputAction>: Publisher {
    // markdown: effect-output.md
    /// Output action matching middleware's `OutputActionType`, wrapped in a `EffectOutput<OutputActionType>` so the action dispatcher can also be 
    /// collected.
    public typealias Output = EffectOutput<OutputAction>
    // markdown: effect-failure.md
    /// `Effect` publisher/observable can't fail.
    public typealias Failure = Never
    // markdown: effect-cancellation-token.md
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.
    /// 
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the very unlike scenario where the 
    /// `EffectMiddleware` itself gets deallocated.
    /// 
    /// Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the dictionary keeping 
    /// the effects will cleanup the key with that token.
    /// 
    public let cancellationToken: AnyHashable?
    private let upstream: AnyPublisher<Output, Failure>

    // markdown: effect-init.md
    /// Create an effect with any upstream as long as it can't fail. Don't use eager publishers as upstream, such as Future, as they will unexpectedly 
    /// start the side-effect before the subscription.
    /// - Parameters:
    ///   - upstream: an upstream Publisher that can't fail and should not be eager.
    public init<P: Publisher>(upstream: P) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = nil
    }

    // markdown: effect-init.md
    /// Create an effect with any upstream as long as it can't fail. Don't use eager publishers as upstream, such as Future, as they will unexpectedly 
    /// start the side-effect before the subscription.
    /// - Parameters:
    ///   - upstream: an upstream Publisher that can't fail and should not be eager.
    ///   - cancellationToken: Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect 
    /// is subscribed to, the subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If 
    /// another effect with the same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  
    /// If you don't want this, not providing a cancellation token will only cancel your Effect in the very unlike scenario where the 
    /// `EffectMiddleware` itself gets deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of 
    /// running effects, that way, the dictionary keeping the effects will cleanup the key with that token. 
    public init<P: Publisher, H: Hashable>(upstream: P, cancellationToken: H) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = cancellationToken
    }

    // markdown: publisher-receive.md
    /// This function is called to attach the specified `Subscriber` to this `Publisher` by `subscribe(_:)`
    /// 
    /// - SeeAlso: `subscribe(_:)`
    /// - Parameters:
    ///   - subscriber: The subscriber to attach to this `Publisher`. Once attached it can begin to receive values.
    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        upstream.subscribe(subscriber)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    // markdown: effect-cancellation.md
    /// Adds a cancellation token to an Effect. This will re-wrap the upstream in a new Effect that also holds the cancellation token.
    /// 
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  If you don't want this, 
    /// not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets 
    /// deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the 
    /// dictionary keeping the effects will cleanup the key with that token. 
    /// 
    /// - Parameters:
    ///   - token: any hashable you want.
    /// - Returns: a new `Effect` instance, wrapping the upstream of original Effect but also holding the cancellation token.
    public func cancellation<H: Hashable>(token: H) -> Effect {
        Effect(upstream: self.upstream, cancellationToken: token)
    }

    // markdown: effect-donothing.md
    /// An Empty effect that will complete immediately without emitting any output. Useful for when the Middleware doesn't want to perform any 
    /// side-effect.
    public static var doNothing: Effect {
        Empty().asEffect(dispatcher: .here())
    }

    // markdown: effect-just.md
    /// A synchronous side-effect that just wraps a single value to be published before the completion.
    /// It lifts a plain value into an `Effect`.
    /// - Parameters:
    ///   - value: the one and only output to be published, synchronously, before the effect completes.
    ///   - dispatcher: The action source, so the Store and other middlewares know where this action is coming from. Default value is 
    /// `ActionSource.here()`, referring to this line as the source. It can be customized for better logging results.
    /// - Returns: an `Effect` that will publish the given value upon subscription, and then complete, immediately.
    /// 
    public static func just(_ value: OutputAction, from dispatcher: ActionSource = .here()) -> Effect {
        Just(value).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-sequence.md
    /// A synchronous side-effect that just wraps a sequence of values to be published before the completion.
    /// It lifts a plain sequence of values into an `Effect`.
    /// - Parameters:
    ///   - values: the sequence of output values to be published, synchronously, before the effect completes.
    ///   - dispatcher: The action source, so the Store and other middlewares know where this action is coming from. Default value is 
    /// `ActionSource.here()`, referring to this line as the source. It can be customized for better logging results.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: OutputAction..., from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-sequence.md
    /// A synchronous side-effect that just wraps a sequence of values to be published before the completion.
    /// It lifts a plain sequence of values into an `Effect`.
    /// - Parameters:
    ///   - values: the sequence of output values to be published, synchronously, before the effect completes.
    ///   - dispatcher: The action source, so the Store and other middlewares know where this action is coming from. Default value is 
    /// `ActionSource.here()`, referring to this line as the source. It can be customized for better logging results.
    /// - Returns: an `Effect` that will publish the given values upon subscription, and then complete, immediately.
    public static func sequence(_ values: [OutputAction], from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-promise.md
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
    /// - Parameters:
    ///   - operation: a closure that gives you a completion handler to be called once the async task is done
    /// - Returns: an `Effect` that will eventually publish the given output when you call the completion handler and that will only call your async 
    /// task once it's subscribed by the Effect Middleware. Then, it will complete immediately as soon as it emits the first value.
    public static func promise(_ operation: @escaping ((Output) -> Void) -> Void) -> Effect {
        Deferred {
            Future { completion in
                operation { callback in
                    completion(.success(callback))
                }
            }
        }.asEffect()
    }

    public static func fireAndForget(_ operation: @escaping () -> Void) -> Effect {
        Empty()
            .handleEvents(receiveSubscription: { _ in operation() })
            .asEffect(dispatcher: .here())
    }

    public static func fireAndForget<P: Publisher>(_ publisher: P) -> Effect where P.Failure == Never {
        publisher
            .ignoreOutput()
            .map { _ -> Output in }
            .asEffect()
    }

    public static func fireIgnoreOutput<P: Publisher>(_ publisher: P, catchErrors: @escaping (P.Failure) -> Output?) -> Effect {
        publisher
            .ignoreOutput()
            .map { _ -> Output? in }
            .catch { error -> Just<Output?> in
                Just(catchErrors(error))
            }
            .compactMap { $0 }
            .asEffect()
    }

    public func prepend(_ effect: Effect) -> Effect {
        .merge(effect, self)
    }

    public func append(_ effect: Effect) -> Effect {
        .merge(self, effect)
    }

    public func fmap<NewOutputAction>(_ transform: @escaping (OutputAction) -> NewOutputAction) -> Effect<NewOutputAction> {
        .init(upstream: map { effectOutput in effectOutput.map(transform) },
              cancellationToken: cancellationToken)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    // markdown: effect-merge.md
    /// Merges multiple effects into one. This will result in an effect that will execute the given effects in parallel, with subscription starting 
    /// with the order provided but delivering output values in the order they arrive from any of the merged effects.
    /// 
    /// - Parameters:
    ///   - first: any effect to have its elements merged into the final effect stream
    ///   - second: any effect to have its elements merged into the final effect stream
    /// - Returns: an Effect that will subscribe to all upstream effects provided above, and will combine their elements as they arrive.
    public static func merge(_ first: Effect, _ second: Effect) -> Effect {
        first.merge(with: second).asEffect()
    }

    // markdown: effect-merge.md
    /// Merges multiple effects into one. This will result in an effect that will execute the given effects in parallel, with subscription starting 
    /// with the order provided but delivering output values in the order they arrive from any of the merged effects.
    /// 
    /// - Parameters:
    ///   - first: any effect to have its elements merged into the final effect stream
    ///   - second: any effect to have its elements merged into the final effect stream
    ///   - third: any effect to have its elements merged into the final effect stream
    /// - Returns: an Effect that will subscribe to all upstream effects provided above, and will combine their elements as they arrive.
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect) -> Effect {
        first.merge(with: second).merge(with: third).asEffect()
    }

    // markdown: effect-merge.md
    /// Merges multiple effects into one. This will result in an effect that will execute the given effects in parallel, with subscription starting 
    /// with the order provided but delivering output values in the order they arrive from any of the merged effects.
    /// 
    /// - Parameters:
    ///   - first: any effect to have its elements merged into the final effect stream
    ///   - second: any effect to have its elements merged into the final effect stream
    ///   - third: any effect to have its elements merged into the final effect stream
    ///   - fourth: any effect to have its elements merged into the final effect stream
    /// - Returns: an Effect that will subscribe to all upstream effects provided above, and will combine their elements as they arrive.
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect, _ fourth: Effect) -> Effect {
        first.merge(with: second, third, fourth).asEffect()
    }

    // markdown: effect-merge.md
    /// Merges multiple effects into one. This will result in an effect that will execute the given effects in parallel, with subscription starting 
    /// with the order provided but delivering output values in the order they arrive from any of the merged effects.
    /// 
    /// - Parameters:
    ///   - first: any effect to have its elements merged into the final effect stream
    ///   - second: any effect to have its elements merged into the final effect stream
    ///   - third: any effect to have its elements merged into the final effect stream
    ///   - fourth: any effect to have its elements merged into the final effect stream
    ///   - fifth: any effect to have its elements merged into the final effect stream
    /// - Returns: an Effect that will subscribe to all upstream effects provided above, and will combine their elements as they arrive.
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect, _ fourth: Effect, _ fifth: Effect) -> Effect {
        first.merge(with: second, third, fourth, fifth).asEffect()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Failure == Never {
    // markdown: effect-as-effect.md
    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already happening before the subscription.
    /// 
    /// An optional cancellation token can be provided to avoid duplicated effect of the same time, or for manual cancellation at any point later.
    /// 
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  If you don't want this, 
    /// not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets 
    /// deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the 
    /// dictionary keeping the effects will cleanup the key with that token. 
    /// 
    /// If the Publisher outputs some `EffectOutput<OutputAction>` events, then the action source (dispatcher) is already known, it's the line that 
    /// created the EffectOutput instance. However, if the upstream Publisher outputs only `OutputAction`, then a `dispatcher: ActionSource` must also 
    /// be provided so the Store knows where this action is coming from. In that case you can provide `ActionSource.here()` if this line of code is to 
    /// be referred as the source.
    /// 
    /// - Parameters:
    ///   - dispatcher: the action source, so the Store and other middlewares know where this action is coming from. You can provide 
    /// `ActionSource.here()` if this line of code is to be referred as the source. A better way is to set the upstream Publisher Output Type as 
    /// `EffectOutput<OutputAction>`, not `OutputAction`, so once you create the `EffectOutput` is set as the action source, providing a better 
    /// logging results for you.
    /// - Returns: an `Effect` wrapping this Publisher as its upstream.
    public func asEffect(dispatcher: ActionSource) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher) })
    }

    // markdown: effect-as-effect.md
    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already happening before the subscription.
    /// 
    /// An optional cancellation token can be provided to avoid duplicated effect of the same time, or for manual cancellation at any point later.
    /// 
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  If you don't want this, 
    /// not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets 
    /// deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the 
    /// dictionary keeping the effects will cleanup the key with that token. 
    /// 
    /// If the Publisher outputs some `EffectOutput<OutputAction>` events, then the action source (dispatcher) is already known, it's the line that 
    /// created the EffectOutput instance. However, if the upstream Publisher outputs only `OutputAction`, then a `dispatcher: ActionSource` must also 
    /// be provided so the Store knows where this action is coming from. In that case you can provide `ActionSource.here()` if this line of code is to 
    /// be referred as the source.
    /// 
    /// - Parameters:
    ///   - dispatcher: the action source, so the Store and other middlewares know where this action is coming from. You can provide 
    /// `ActionSource.here()` if this line of code is to be referred as the source. A better way is to set the upstream Publisher Output Type as 
    /// `EffectOutput<OutputAction>`, not `OutputAction`, so once you create the `EffectOutput` is set as the action source, providing a better 
    /// logging results for you.
    ///   - cancellationToken: cancellation token for this effect, as explained in the method description
    /// - Returns: an `Effect` wrapping this Publisher as its upstream.
    public func asEffect<H: Hashable>(dispatcher: ActionSource, cancellationToken: H) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher) }, cancellationToken: cancellationToken)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Output: EffectOutputProtocol, Failure == Never {
    // markdown: effect-as-effect.md
    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already happening before the subscription.
    /// 
    /// An optional cancellation token can be provided to avoid duplicated effect of the same time, or for manual cancellation at any point later.
    /// 
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  If you don't want this, 
    /// not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets 
    /// deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the 
    /// dictionary keeping the effects will cleanup the key with that token. 
    /// 
    /// If the Publisher outputs some `EffectOutput<OutputAction>` events, then the action source (dispatcher) is already known, it's the line that 
    /// created the EffectOutput instance. However, if the upstream Publisher outputs only `OutputAction`, then a `dispatcher: ActionSource` must also 
    /// be provided so the Store knows where this action is coming from. In that case you can provide `ActionSource.here()` if this line of code is to 
    /// be referred as the source.
    /// 
    /// - Returns: an `Effect` wrapping this Publisher as its upstream.
    public func asEffect() -> Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) })
    }

    // markdown: effect-as-effect.md
    /// Erases any unfailable Publisher to effect. Don't call this on eager Publishers or the effect is already happening before the subscription.
    /// 
    /// An optional cancellation token can be provided to avoid duplicated effect of the same time, or for manual cancellation at any point later.
    /// 
    /// Cancellation token is any hashable used later to eventually cancel this effect before its completion. Once this effect is subscribed to, the 
    /// subscription (in form of `AnyCancellable`) will be kept in a dictionary where the key is this cancellation token. If another effect with the 
    /// same cancellation token arrives, the former will be immediately replaced in the dictionary and, therefore, cancelled.  If you don't want this, 
    /// not providing a cancellation token will only cancel your Effect in the very unlike scenario where the `EffectMiddleware` itself gets 
    /// deallocated.  Cancellation tokens can also be provided to the `EffectMiddleware` to force cancellation of running effects, that way, the 
    /// dictionary keeping the effects will cleanup the key with that token. 
    /// 
    /// If the Publisher outputs some `EffectOutput<OutputAction>` events, then the action source (dispatcher) is already known, it's the line that 
    /// created the EffectOutput instance. However, if the upstream Publisher outputs only `OutputAction`, then a `dispatcher: ActionSource` must also 
    /// be provided so the Store knows where this action is coming from. In that case you can provide `ActionSource.here()` if this line of code is to 
    /// be referred as the source.
    /// 
    /// - Parameters:
    ///   - cancellationToken: cancellation token for this effect, as explained in the method description
    /// - Returns: an `Effect` wrapping this Publisher as its upstream.
    public func asEffect<H: Hashable>(cancellationToken: H) -> Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) },
                                   cancellationToken: cancellationToken)
    }
}
#endif
