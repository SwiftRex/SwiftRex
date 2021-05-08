import Foundation
import ReactiveSwift
import SwiftRex

public struct Effect<Dependencies, OutputAction> {
    public typealias ToCancel = (AnyHashable) -> FireAndForget<DispatchedAction<OutputAction>>
    public typealias Context = (dependencies: Dependencies, toCancel: ToCancel)

    private let _run: ((Context) -> SignalProducer<DispatchedAction<OutputAction>, Never>)?
    public var doesSomething: Bool { _run != nil }
    public let token: AnyHashable?

    public init<H: Hashable, S: SignalProducerProtocol>(token: H, effect: @escaping (Context) -> S)
    where S.Value == DispatchedAction<OutputAction>, S.Error == Never {
        self.token = token
        self._run = { context in effect(context).producer }
    }

    public init<S: SignalProducerProtocol>(effect: @escaping (Context) -> S) where S.Value == DispatchedAction<OutputAction>, S.Error == Never {
        self.token = nil
        self._run = { context in effect(context).producer }
    }

    private init() {
        self.token = nil
        self._run = nil
    }

    public static var doNothing: Effect {
        .init()
    }

    public func run(_ context: Context) -> SignalProducer<DispatchedAction<OutputAction>, Never>? {
        _run?(context)
    }

    public func map<NewOutputAction>(_ transform: @escaping (OutputAction) -> NewOutputAction) -> Effect<Dependencies, NewOutputAction> {
        guard let run = self._run else { return .doNothing }

        func map(creator: @escaping (Effect<Dependencies, OutputAction>.Context) -> SignalProducer<DispatchedAction<OutputAction>, Never>)
        -> (Effect<Dependencies, NewOutputAction>.Context)
        -> SignalProducer<DispatchedAction<NewOutputAction>, Never> {
            { newContext in
                let oldContext = Effect<Dependencies, OutputAction>.Context(
                    dependencies: newContext.dependencies,
                    toCancel: { (token: AnyHashable) -> FireAndForget<DispatchedAction<OutputAction>> in
                        FireAndForget(newContext.toCancel(token))
                    }
                )

                return creator(oldContext).map { $0.map(transform) }
            }
        }

        return self.token.map {
            return Effect<Dependencies, NewOutputAction>(token: $0, effect: map(creator: run))
        } ?? Effect<Dependencies, NewOutputAction>(effect: map(creator: run))
    }
}

extension Effect where Dependencies == Void {
    public init<H: Hashable, S: SignalProducerProtocol>(token: H, effect: S)
    where S.Value == DispatchedAction<OutputAction>, S.Error == Never {
        self.token = token
        self._run = { _ in effect.producer }
    }

    public init<S: SignalProducerProtocol>(_ effect: S) where S.Value == DispatchedAction<OutputAction>, S.Error == Never {
        self.token = nil
        self._run = { _ in effect.producer }
    }

    public func ignoringDependencies<T>() -> Effect<T, OutputAction> {
        guard let run = self._run else { return .doNothing }

        return self.token.map {
            Effect<T, OutputAction>(token: $0) { context in
                run((dependencies: (), toCancel: context.toCancel)).producer
            }
        } ?? Effect<T, OutputAction> { context in
            run((dependencies: (), toCancel: context.toCancel)).producer
        }
    }
}

extension Effect {
    public static func fireAndForget<S: SignalProducerProtocol>(_ upstream: @escaping (Context) -> S) -> Effect<Dependencies, OutputAction>
    where S.Error == Never {
        Effect { context in
            FireAndForget(upstream(context))
        }
    }

    public static func fireAndForget<S: SignalProducerProtocol>(
        _ upstream: @escaping (Context) -> S,
        catchErrors: @escaping (S.Error) -> DispatchedAction<OutputAction>?
    ) -> Effect<Dependencies, OutputAction> {
        Effect { context in
            FireAndForget(upstream(context), catchErrors: catchErrors)
        }
    }

    public static func fireAndForget(_ operation: @escaping (Context) -> Void) -> Effect<Dependencies, OutputAction> {
        Effect { context in
            FireAndForget { operation(context) }
        }
    }
}

extension Effect where Dependencies == Void {
    public static func fireAndForget<S: SignalProducerProtocol>(_ upstream: S) -> Effect<Dependencies, OutputAction> where S.Error == Never {
        Effect { _ in
            FireAndForget(upstream)
        }
    }

    public static func fireAndForget<S: SignalProducerProtocol>(_ upstream: S, catchErrors: @escaping (S.Error) -> DispatchedAction<OutputAction>?)
    -> Effect<Dependencies, OutputAction> {
        Effect { _ in
            FireAndForget(upstream, catchErrors: catchErrors)
        }
    }

    public static func fireAndForget(_ operation: @escaping () -> Void) -> Effect<Dependencies, OutputAction> {
        Effect { _ in
            FireAndForget(operation)
        }
    }
}

extension Effect {
    public static func just(_ value: OutputAction, from dispatcher: ActionSource) -> Effect {
        Effect { _ in
            SignalProducer(value: DispatchedAction(value, dispatcher: dispatcher))
        }
    }

    public static func just(
        _ value: OutputAction,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect {
        just(value, from: ActionSource(file: file, function: function, line: line, info: info))
    }

    public static func sequence(_ values: OutputAction..., from dispatcher: ActionSource) -> Effect {
        Effect { _ in
            SignalProducer(values).map { DispatchedAction($0, dispatcher: dispatcher) }
        }
    }

    public static func sequence(
        _ values: OutputAction...,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect {
        sequence(values, from: ActionSource(file: file, function: function, line: line, info: info))
    }

    public static func sequence(_ values: [OutputAction], from dispatcher: ActionSource) -> Effect {
        Effect { _ in
            SignalProducer(values).map { DispatchedAction($0, dispatcher: dispatcher) }
        }
    }

    public static func sequence(
        _ values: [OutputAction],
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect {
        sequence(values, from: ActionSource(file: file, function: function, line: line, info: info))
    }

    public static func promise<H: Hashable>(
        token: H,
        from dispatcher: ActionSource,
        perform: @escaping (Context, @escaping (OutputAction) -> Void) -> Disposable
    ) -> Effect {
        Effect<Dependencies, OutputAction> { context in
            SignalProducer { observer, lifetime in
                lifetime += perform(context) { outputAction in
                    observer.send(value: DispatchedAction(outputAction, dispatcher: dispatcher))
                    observer.sendCompleted()
                }
            }
        }
    }

    public static func promise<H: Hashable>(
        token: H,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil,
        perform: @escaping (Context, @escaping (OutputAction) -> Void) -> Disposable
    ) -> Effect {
        promise(token: token,
                from: ActionSource(file: file, function: function, line: line, info: info),
                perform: perform)
    }

    public static func toCancel<H: Hashable>(_ token: H) -> Effect {
        Effect<Dependencies, OutputAction> { context in
            context.toCancel(token)
        }
    }
}

extension SignalProducerProtocol where Error == Never {
    public func asEffect<H: Hashable>(token: H, dispatcher: ActionSource) -> Effect<Void, Value> {
        Effect(token: token, effect: { _ in producer.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect<H: Hashable>(
        token: H,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Value> {
        asEffect(token: token, dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }

    public func asEffect(dispatcher: ActionSource) -> Effect<Void, Value> {
        Effect(effect: { _ in producer.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Value> {
        asEffect(dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }
}
