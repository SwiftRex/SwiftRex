// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
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
    override func handle(action: ActionProtocol) -> Void {
        return concrete.handle(action: action)
    }

    override var context: (() -> MiddlewareContext<StateType>) {
        get { return concrete.context }
        set { concrete.context = newValue }
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
     Proxy method for `Middleware.handle(action:)`
     */
    public func handle(action: ActionProtocol) -> Void {
        return box.handle(action: action)
    }

    /**
     Proxy property for `Middleware.context`
     */
    public var context: (() -> MiddlewareContext<StateType>) {
        get { return box.context }
        set { box.context = newValue }
    }
}
