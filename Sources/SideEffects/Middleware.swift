// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol Middleware: class {
    associatedtype StateType
    var actionHandler: ActionHandler? { get set }
    func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>)
    func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>)
}
