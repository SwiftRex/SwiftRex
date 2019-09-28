import SwiftRex

class MiddlewareContextMock {
    let actionHandlerMock = ActionHandlerMock()
    let eventHandlerMock = EventHandlerMock()
    var value: MiddlewareContext

    init() {
        value = MiddlewareContext(
            actionHandler: actionHandlerMock.value,
            eventHandler: eventHandlerMock.value
        )
    }
}
