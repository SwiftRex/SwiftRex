#if canImport(Combine)
import SwiftRex

class MessageHandlerMock {
    let actionHandlerMock = ActionHandlerMock()
    let eventHandlerMock = EventHandlerMock()
    var value: MessageHandler!

    init() {
        value = MessageHandler(
            actionHandler: actionHandlerMock.value,
            eventHandler: eventHandlerMock.value
        )
    }
}
#endif
