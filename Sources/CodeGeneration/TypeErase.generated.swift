// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

import RxSwift

// MARK: - Type Eraser for Middleware

private class _AnyMiddlewareBase<StateType>: Middleware {
    init() {
        guard type(of: self) != _AnyMiddlewareBase.self else {
            fatalError("_AnyMiddlewareBase<StateType> instances can not be created; create a subclass instance instead")
        }
    }

    func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        fatalError("Must override")
    }
    func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) -> Void {
        fatalError("Must override")
    }

    var actionHandler: ActionHandler? {
        get { fatalError("Must override") }
        set { fatalError("Must override") }
    }
}

private final class _AnyMiddlewareBox<Concrete: Middleware>: _AnyMiddlewareBase<Concrete.StateType> {
    var concrete: Concrete
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        return concrete.handle(event: event, getState: getState, next: next)
    }
    override func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) -> Void {
        return concrete.handle(action: action, getState: getState, next: next)
    }

    override var actionHandler: ActionHandler? {
        get { return concrete.actionHandler }
        set { concrete.actionHandler = newValue }
    }
}

public final class AnyMiddleware<StateType>: Middleware {
    private let box: _AnyMiddlewareBase<StateType>

    public init<Concrete: Middleware>(_ concrete: Concrete) where Concrete.StateType == StateType {
        self.box = _AnyMiddlewareBox(concrete)
    }

    public func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        return box.handle(event: event,getState: getState,next: next)
    }
    public func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) -> Void {
        return box.handle(action: action,getState: getState,next: next)
    }

    public var actionHandler: ActionHandler? {
        get { return box.actionHandler }
        set { box.actionHandler = newValue }
    }
}
// MARK: - Type Eraser for Reducer

private class _AnyReducerBase<StateType>: Reducer {
    init() {
        guard type(of: self) != _AnyReducerBase.self else {
            fatalError("_AnyReducerBase<StateType> instances can not be created; create a subclass instance instead")
        }
    }

    func reduce(_ currentState: StateType, action: Action) -> StateType {
        fatalError("Must override")
    }

}

private final class _AnyReducerBox<Concrete: Reducer>: _AnyReducerBase<Concrete.StateType> {
    var concrete: Concrete
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func reduce(_ currentState: StateType, action: Action) -> StateType {
        return concrete.reduce(currentState, action: action)
    }

}

public final class AnyReducer<StateType>: Reducer {
    private let box: _AnyReducerBase<StateType>

    public init<Concrete: Reducer>(_ concrete: Concrete) where Concrete.StateType == StateType {
        self.box = _AnyReducerBox(concrete)
    }

    public func reduce(_ currentState: StateType, action: Action) -> StateType {
        return box.reduce(currentState,action: action)
    }

}
// MARK: - Type Eraser for SideEffectProducer

private class _AnySideEffectProducerBase<StateType>: SideEffectProducer {
    init() {
        guard type(of: self) != _AnySideEffectProducerBase.self else {
            fatalError("_AnySideEffectProducerBase<StateType> instances can not be created; create a subclass instance instead")
        }
    }

    func handle(event: Event, getState: @escaping GetState<StateType>) -> Observable<Action> {
        fatalError("Must override")
    }

}

private final class _AnySideEffectProducerBox<Concrete: SideEffectProducer>: _AnySideEffectProducerBase<Concrete.StateType> {
    var concrete: Concrete
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func handle(event: Event, getState: @escaping GetState<StateType>) -> Observable<Action> {
        return concrete.handle(event: event, getState: getState)
    }

}

public final class AnySideEffectProducer<StateType>: SideEffectProducer {
    private let box: _AnySideEffectProducerBase<StateType>

    public init<Concrete: SideEffectProducer>(_ concrete: Concrete) where Concrete.StateType == StateType {
        self.box = _AnySideEffectProducerBox(concrete)
    }

    public func handle(event: Event, getState: @escaping GetState<StateType>) -> Observable<Action> {
        return box.handle(event: event,getState: getState)
    }

}
