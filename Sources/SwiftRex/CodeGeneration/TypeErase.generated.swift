// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



// MARK: - Type Eraser for Middleware

private final class _AnyMiddlewareBox<Concrete: Middleware>: _AnyMiddlewareBase<Concrete.InputActionType, Concrete.OutputActionType, Concrete.StateType> {
    var concrete: Concrete
    typealias InputActionType = Concrete.InputActionType
    typealias OutputActionType = Concrete.OutputActionType
    typealias StateType = Concrete.StateType

    init(_ concrete: Concrete) {
        self.concrete = concrete
    }

    override func handle(action: InputActionType, next: @escaping Next) -> Void {
        return concrete.handle(action: action, next: next)
    }

    override var context: (() -> MiddlewareContext<OutputActionType, StateType>) {
        get { return concrete.context }
        set { concrete.context = newValue }
    }
}

/**
 Type-erased `Middleware`
 */
public final class AnyMiddleware<InputActionType, OutputActionType, StateType>: Middleware {
    private let box: _AnyMiddlewareBase<InputActionType, OutputActionType, StateType>

    /**
     Default initializer for `AnyMiddleware`

     - Parameter concrete: Concrete type that implements `Middleware`
    */
    public init<Concrete: Middleware>(_ concrete: Concrete) where
        Concrete.InputActionType == InputActionType,
        Concrete.OutputActionType == OutputActionType,
        Concrete.StateType == StateType { 
        self.box = _AnyMiddlewareBox(concrete)
    }

    /**
     Proxy method for `Middleware.handle(action:next:)`
     */
    public func handle(action: InputActionType, next: @escaping Next) -> Void {
        return box.handle(action: action,next: next)
    }

    /**
     Proxy property for `Middleware.context`
     */
    public var context: (() -> MiddlewareContext<OutputActionType, StateType>) {
        get { return box.context }
        set { box.context = newValue }
    }
}
