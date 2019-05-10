// Generated using Sourcery 0.16.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



// MARK: - Type Eraser for Middleware

private final class _AnyMiddlewareBox<Concrete: Middleware>: _AnyMiddlewareBase<Concrete.StateType> {
    var concrete: Concrete
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        return concrete.handle(event: event, getState: getState, next: next)
    }
    override func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) -> Void {
        return concrete.handle(action: action, getState: getState, next: next)
    }

    override var actionHandler: ActionHandler? {
        get { return concrete.actionHandler }
        set { concrete.actionHandler = newValue }
    }
}

/**
 Type-erased `Middleware`
 */
public final class AnyMiddleware<StateType>: Middleware {
    private let box: _AnyMiddlewareBase<StateType>

    /**
     Default initializer for `AnyMiddleware`

     - Parameter concrete: Concrete type that implements `Middleware`
    */
    public init<Concrete: Middleware>(_ concrete: Concrete) where Concrete.StateType == StateType {
        self.box = _AnyMiddlewareBox(concrete)
    }

    /**
     Proxy method for `Middleware.handle(event:getState:next:)`
     */
    public func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        return box.handle(event: event,getState: getState,next: next)
    }

    /**
     Proxy method for `Middleware.handle(action:getState:next:)`
     */
    public func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) -> Void {
        return box.handle(action: action,getState: getState,next: next)
    }

    /**
     Proxy property for `Middleware.actionHandler`
     */
    public var actionHandler: ActionHandler? {
        get { return box.actionHandler }
        set { box.actionHandler = newValue }
    }
}

// MARK: - Type Eraser for SideEffectProducer

private final class _AnySideEffectProducerBox<Concrete: SideEffectProducer>: _AnySideEffectProducerBase<Concrete.StateType> {
    var concrete: Concrete
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func execute(getState: @escaping GetState<StateType>) -> FailableObservableSignalProducer<ActionProtocol> {
        return concrete.execute(getState: getState)
    }

}

/**
 Type-erased `SideEffectProducer`
 */
public final class AnySideEffectProducer<StateType>: SideEffectProducer {
    private let box: _AnySideEffectProducerBase<StateType>

    /**
     Default initializer for `AnySideEffectProducer`

     - Parameter concrete: Concrete type that implements `SideEffectProducer`
    */
    public init<Concrete: SideEffectProducer>(_ concrete: Concrete) where Concrete.StateType == StateType {
        self.box = _AnySideEffectProducerBox(concrete)
    }

    /**
     Proxy method for `SideEffectProducer.execute(getState:)`
     */
    public func execute(getState: @escaping GetState<StateType>) -> FailableObservableSignalProducer<ActionProtocol> {
        return box.execute(getState: getState)
    }

}
