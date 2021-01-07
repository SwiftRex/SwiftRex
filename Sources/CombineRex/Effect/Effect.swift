#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public struct Effect<Dependencies, OutputAction> {
    public typealias ToCancel = (AnyHashable) -> FireAndForget<DispatchedAction<OutputAction>>
    public typealias Context = (dependencies: Dependencies, toCancel: ToCancel)

    private let _run: ((Context) -> AnyPublisher<DispatchedAction<OutputAction>, Never>)?
    public var doesSomething: Bool { _run != nil }
    public let token: AnyHashable?

    public init<H: Hashable, P: Publisher>(token: H, effect: @escaping (Context) -> P)
    where P.Output == DispatchedAction<OutputAction>, P.Failure == Never {
        self.token = token
        self._run = { context in effect(context).eraseToAnyPublisher() }
    }

    public init<P: Publisher>(effect: @escaping (Context) -> P) where P.Output == DispatchedAction<OutputAction>, P.Failure == Never {
        self.token = nil
        self._run = { context in effect(context).eraseToAnyPublisher() }
    }

    private init() {
        self.token = nil
        self._run = nil
    }

    public static var doNothing: Effect {
        .init()
    }

    public func run(_ context: Context) -> AnyPublisher<DispatchedAction<OutputAction>, Never>? {
        _run?(context)
    }

    public func map<NewOutputAction>(_ transform: @escaping (OutputAction) -> NewOutputAction) -> Effect<Dependencies, NewOutputAction> {
        guard let run = self._run else { return .doNothing }

        func map(creator: @escaping (Effect<Dependencies, OutputAction>.Context) -> AnyPublisher<DispatchedAction<OutputAction>, Never>)
        -> (Effect<Dependencies, NewOutputAction>.Context)
        -> Publishers.Map<AnyPublisher<DispatchedAction<OutputAction>, Never>, DispatchedAction<NewOutputAction>> {
            { newContext in
                let oldContext = Effect<Dependencies, OutputAction>.Context(
                    dependencies: newContext.dependencies,
                    toCancel: { token in FireAndForget(newContext.toCancel(token)) }
                )

                return creator(oldContext).map { $0.map(transform) }
            }
        }

        if let token = self.token {
            return Effect<Dependencies, NewOutputAction>(token: token, effect: map(creator: run))
        } else {
            return Effect<Dependencies, NewOutputAction>(effect: map(creator: run))
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect where Dependencies == Void {
    public init<H: Hashable, P: Publisher>(token: H, effect: P)
    where P.Output == DispatchedAction<OutputAction>, P.Failure == Never {
        self.token = token
        self._run = { _ in effect.eraseToAnyPublisher() }
    }

    public init<P: Publisher>(_ effect: P) where P.Output == DispatchedAction<OutputAction>, P.Failure == Never {
        self.token = nil
        self._run = { _ in effect.eraseToAnyPublisher() }
    }

    public func ignoringDependencies<T>() -> Effect<T, OutputAction> {
        guard let run = self._run else { return .doNothing }

        if let token = self.token {
            return Effect<T, OutputAction>(token: token) { context in
                run((dependencies: (), toCancel: context.toCancel) ).eraseToAnyPublisher()
            }
        } else {
            return Effect<T, OutputAction> { context in
                run((dependencies: (), toCancel: context.toCancel) ).eraseToAnyPublisher()
            }
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    public static func fireAndForget<P: Publisher>(_ upstream: @escaping (Context) -> P) -> Effect<Dependencies, OutputAction>
    where P.Failure == Never {
        Effect { context in
            FireAndForget(upstream(context))
        }
    }

    public static func fireAndForget<P: Publisher>(
        _ upstream: @escaping (Context) -> P,
        catchErrors: @escaping (P.Failure) -> DispatchedAction<OutputAction>?
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect where Dependencies == Void {
    public static func fireAndForget<P: Publisher>(_ upstream: P) -> Effect<Dependencies, OutputAction> where P.Failure == Never {
        Effect { _ in
            FireAndForget(upstream)
        }
    }

    public static func fireAndForget<P: Publisher>(_ upstream: P, catchErrors: @escaping (P.Failure) -> DispatchedAction<OutputAction>?)
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Effect {
    public static func just(_ value: OutputAction, from dispatcher: ActionSource) -> Effect {
        Effect { _ in
            Just(DispatchedAction(value, dispatcher: dispatcher))
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
            values.publisher.map { DispatchedAction($0, dispatcher: dispatcher) }
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
            values.publisher.map { DispatchedAction($0, dispatcher: dispatcher) }
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
        perform: @escaping (Context, @escaping (OutputAction) -> Void) -> Void
    ) -> Effect {
        Effect<Dependencies, OutputAction> { context in
            Deferred<Future<DispatchedAction<OutputAction>, Never>> {
                Future { completion in
                    perform(context) { outputAction in
                        completion(.success(DispatchedAction(outputAction, dispatcher: dispatcher)))
                    }
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
        perform: @escaping (Context, @escaping (OutputAction) -> Void) -> Void
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

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension Publisher where Failure == Never {
    public func asEffect<H: Hashable>(token: H, dispatcher: ActionSource) -> Effect<Void, Output> {
        Effect(token: token, effect: { _ in self.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect<H: Hashable>(
        token: H,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Output> {
        asEffect(token: token, dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }

    public func asEffect(dispatcher: ActionSource) -> Effect<Void, Output> {
        Effect(effect: { _ in self.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Output> {
        asEffect(dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }
}
#endif
