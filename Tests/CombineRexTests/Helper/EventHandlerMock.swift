import SwiftRex

class EventHandlerMock {
    var events: [EventProtocol] = []
    var value: EventHandler!

    init() {
        value = EventHandler(
            onValue: { [unowned self] event in self.events.append(event) }
        )
    }
}
