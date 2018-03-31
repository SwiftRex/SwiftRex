// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol Middleware: class {
    associatedtype StateType
    func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping (Event, @escaping GetState<StateType>) -> Void)
    func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping (Action, @escaping GetState<StateType>) -> Void)
}
