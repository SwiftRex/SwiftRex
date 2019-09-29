import SwiftRex

class ActionHandlerMock {
    var actions: [ActionMock] = []
    var value: ActionHandler<ActionMock>!

    init() {
        value = ActionHandler(
            onValue: { [unowned self] action in self.actions.append(action) }
        )
    }
}
