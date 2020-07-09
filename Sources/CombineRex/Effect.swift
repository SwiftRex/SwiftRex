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

// markdown: effect.md
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct Effect<OutputAction>: Publisher {
    // markdown: effect-output.md
    public typealias Output = EffectOutput<OutputAction>
    // markdown: effect-failure.md
    public typealias Failure = Never
    // markdown: effect-cancellation-token.md
    public let cancellationToken: AnyHashable?
    private let upstream: AnyPublisher<Output, Failure>

    // markdown: effect-init.md
    public init<P: Publisher>(upstream: P) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = nil
    }

    // markdown: effect-init.md
    public init<P: Publisher, H: Hashable>(upstream: P, cancellationToken: H) where P.Output == Output, P.Failure == Failure {
        self.upstream = upstream.eraseToAnyPublisher()
        self.cancellationToken = cancellationToken
    }

    // markdown: publisher-receive.md
    public func receive<S>(subscriber: S) where S: Subscriber, Self.Failure == S.Failure, Self.Output == S.Input {
        upstream.subscribe(subscriber)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    // markdown: effect-cancellation.md
    public func cancellation<H: Hashable>(token: H) -> Effect {
        Effect(upstream: self.upstream, cancellationToken: token)
    }

    // markdown: effect-donothing.md
    public static var doNothing: Effect {
        Empty().asEffect(dispatcher: .here())
    }

    // markdown: effect-just.md
    public static func just(_ value: OutputAction, from dispatcher: ActionSource = .here()) -> Effect {
        Just(value).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-sequence.md
    public static func sequence(_ values: OutputAction..., from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-sequence.md
    public static func sequence(_ values: [OutputAction], from dispatcher: ActionSource = .here()) -> Effect {
        Publishers.Sequence(sequence: values).asEffect(dispatcher: dispatcher)
    }

    // markdown: effect-promise.md
    public static func promise(_ operation: @escaping ((Output) -> Void) -> Void) -> Effect {
        Deferred {
            Future { completion in
                operation { callback in
                    completion(.success(callback))
                }
            }
        }.asEffect()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    // markdown: effect-merge.md
    public static func merge(_ first: Effect, _ second: Effect) -> Effect {
        first.merge(with: second).asEffect()
    }

    // markdown: effect-merge.md
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect) -> Effect {
        first.merge(with: second).merge(with: third).asEffect()
    }

    // markdown: effect-merge.md
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect, _ fourth: Effect) -> Effect {
        first.merge(with: second, third, fourth).asEffect()
    }

    // markdown: effect-merge.md
    public static func merge(_ first: Effect, _ second: Effect, _ third: Effect, _ fourth: Effect, _ fifth: Effect) -> Effect {
        first.merge(with: second, third, fourth, fifth).asEffect()
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Failure == Never {
    // markdown: effect-as-effect.md
    public func asEffect(dispatcher: ActionSource) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher) })
    }

    // markdown: effect-as-effect.md
    public func asEffect<H: Hashable>(dispatcher: ActionSource, cancellationToken: H) -> Effect<Self.Output> {
        Effect(upstream: self.map { EffectOutput.dispatch($0, from: dispatcher) }, cancellationToken: cancellationToken)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Output: EffectOutputProtocol, Failure == Never {
    // markdown: effect-as-effect.md
    public func asEffect() -> Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) })
    }

    // markdown: effect-as-effect.md
    public func asEffect<H: Hashable>(cancellationToken: H) -> Effect<Self.Output.Action> {
        Effect<Self.Output.Action>(upstream: self.map { EffectOutput.dispatch($0.action, from: $0.dispatcher) },
                                   cancellationToken: cancellationToken)
    }
}
#endif
