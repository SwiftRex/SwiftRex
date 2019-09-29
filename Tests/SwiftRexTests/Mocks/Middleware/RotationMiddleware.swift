import SwiftRex

class RotationMiddleware: Middleware {
    var context: () -> MiddlewareContext<ActionMock, TestState> = { fatalError("RotationMiddleware used before it's set") }
    private var name: String

    init(name: String) {
        self.name = name
    }

    func handle(action: ActionMock) {
        let newAction: ActionMock
        switch action {
        case let oldAction as Action1:
            var action2 = Action2()
            action2.value = oldAction.value
            action2.name = oldAction.name + name
            newAction = action2
        case let oldAction as Action2:
            var action3 = Action3()
            action3.value = oldAction.value
            action3.name = oldAction.name + name
            newAction = action3
        case let oldAction as Action3:
            var action1 = Action1()
            action1.value = oldAction.value
            action1.name = oldAction.name + name
            newAction = action1
        default:
            newAction = action
        }

        context().next(newAction)
    }
}
