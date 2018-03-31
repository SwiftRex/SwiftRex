// sourcery: AutoMockable
// sourcery: TypeErase = StateType
public protocol Middleware: class {
    associatedtype StateType
    func handle(event: Event, getState: @escaping () -> StateType, next: @escaping (Event, @escaping () -> StateType) -> Void)
    func handle(action: Action, getState: @escaping () -> StateType, next: @escaping (Action, @escaping () -> StateType) -> Void)
}
