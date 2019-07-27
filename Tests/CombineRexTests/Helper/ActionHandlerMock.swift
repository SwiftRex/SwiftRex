#if canImport(Combine)
import SwiftRex

class ActionHandlerMock {
    var actions: [ActionProtocol] = []
    var value: ActionHandler!

    init() {
        value = ActionHandler(
            onValue: { [unowned self] action in self.actions.append(action) }
        )
    }
}
#endif
