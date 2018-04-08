// sourcery: TypeErase = StateType
public protocol Middleware: class {
    associatedtype StateType
    var actionHandler: ActionHandler? { get set }
    func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>)
    func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>)
}
