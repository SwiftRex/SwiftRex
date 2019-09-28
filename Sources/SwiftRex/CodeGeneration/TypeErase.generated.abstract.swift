// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

@inline(never)
private func _abstract(file: StaticString = #file, line: UInt = #line) -> Never {
    fatalError("Method must be overridden", file: file, line: line)
}

// MARK: - Type Eraser for Middleware

internal class _AnyMiddlewareBase<StateType>: Middleware {
    init() {
        guard type(of: self) != _AnyMiddlewareBase.self else {
            _abstract()
        }
    }

    func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) -> Void {
        _abstract()
    }

    func handle(action: ActionProtocol) -> Void {
        _abstract()
    }

    var context: (() -> MiddlewareContext<StateType>) {
        get { _abstract() }
        set { _abstract() }
    }
}
