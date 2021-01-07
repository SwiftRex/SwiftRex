import Foundation
import RxSwift
import SwiftRex

public struct Effect<Dependencies, OutputAction> {
    public typealias ToCancel = (AnyHashable) -> FireAndForget<DispatchedAction<OutputAction>>
    public typealias Context = (dependencies: Dependencies, toCancel: ToCancel)

    private let _run: ((Context) -> Observable<DispatchedAction<OutputAction>>)?
    public var doesSomething: Bool { _run != nil }
    public let token: AnyHashable?

    public init<H: Hashable, O: ObservableType>(token: H, effect: @escaping (Context) -> O)
    where O.Element == DispatchedAction<OutputAction> {
        self.token = token
        self._run = { context in effect(context).asObservable() }
    }

    public init<O: ObservableType>(effect: @escaping (Context) -> O) where O.Element == DispatchedAction<OutputAction> {
        self.token = nil
        self._run = { context in effect(context).asObservable() }
    }

    private init() {
        self.token = nil
        self._run = nil
    }

    public static var doNothing: Effect {
        .init()
    }

    public func run(_ context: Context) -> Observable<DispatchedAction<OutputAction>>? {
        _run?(context)
    }

    public func map<NewOutputAction>(_ transform: @escaping (OutputAction) -> NewOutputAction) -> Effect<Dependencies, NewOutputAction> {
        guard let run = self._run else { return .doNothing }

        func map(creator: @escaping (Effect<Dependencies, OutputAction>.Context) -> Observable<DispatchedAction<OutputAction>>)
        -> (Effect<Dependencies, NewOutputAction>.Context)
        -> Observable<DispatchedAction<NewOutputAction>> {
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

extension Effect where Dependencies == Void {
    public init<H: Hashable, O: ObservableType>(token: H, effect: O)
    where O.Element == DispatchedAction<OutputAction> {
        self.token = token
        self._run = { _ in effect.asObservable() }
    }

    public init<O: ObservableType>(_ effect: O) where O.Element == DispatchedAction<OutputAction> {
        self.token = nil
        self._run = { _ in effect.asObservable() }
    }

    public func ignoringDependencies<T>() -> Effect<T, OutputAction> {
        guard let run = self._run else { return .doNothing }

        if let token = self.token {
            return Effect<T, OutputAction>(token: token) { context in
                run((dependencies: (), toCancel: context.toCancel) ).asObservable()
            }
        } else {
            return Effect<T, OutputAction> { context in
                run((dependencies: (), toCancel: context.toCancel) ).asObservable()
            }
        }
    }
}

extension Effect {
    public static func fireAndForget<O: ObservableType>(_ upstream: @escaping (Context) -> O) -> Effect<Dependencies, OutputAction> {
        Effect { context in
            FireAndForget(upstream(context))
        }
    }

    public static func fireAndForget<O: ObservableType>(
        _ upstream: @escaping (Context) -> O,
        catchErrors: @escaping (Error) -> DispatchedAction<OutputAction>?
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
    public static func fireAndForget<O: ObservableType>(_ upstream: O) -> Effect<Dependencies, OutputAction> {
        Effect { _ in
            FireAndForget(upstream)
        }
    }

    public static func fireAndForget<O: ObservableType>(_ upstream: O, catchErrors: @escaping (Error) -> DispatchedAction<OutputAction>?)
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
            Observable.just(DispatchedAction(value, dispatcher: dispatcher))
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
            Observable.from(values).map { DispatchedAction($0, dispatcher: dispatcher) }
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
            Observable.from(values).map { DispatchedAction($0, dispatcher: dispatcher) }
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
            Observable.create { observer -> Disposable in
                perform(context) { outputAction in
                    observer.onNext(DispatchedAction(outputAction, dispatcher: dispatcher))
                    observer.onCompleted()
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

extension ObservableType {
    public func asEffect<H: Hashable>(token: H, dispatcher: ActionSource) -> Effect<Void, Element> {
        Effect(token: token, effect: { _ in self.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect<H: Hashable>(
        token: H,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Element> {
        asEffect(token: token, dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }

    public func asEffect(dispatcher: ActionSource) -> Effect<Void, Element> {
        Effect(effect: { _ in self.map { DispatchedAction($0, dispatcher: dispatcher) } })
    }

    public func asEffect(
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        info: String? = nil
    ) -> Effect<Void, Element> {
        asEffect(dispatcher: ActionSource(file: file, function: function, line: line, info: info))
    }
}
