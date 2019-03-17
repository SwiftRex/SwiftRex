import SwiftRex

class RotationMiddleware: Middleware {
    weak var actionHandler: ActionHandler?
    private var name: String

    init(name: String) {
        self.name = name
    }

    func handle(action: ActionProtocol, getState: @escaping GetState<TestState>, next: @escaping NextActionHandler<TestState>) {
        let newAction: ActionProtocol
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

        next(newAction, getState)
    }

    func handle(event: EventProtocol, getState: @escaping GetState<TestState>, next: @escaping NextEventHandler<TestState>) {
        let newEvent: EventProtocol
        switch event {
        case let oldEvent as Event1:
            var event2 = Event2()
            event2.value = oldEvent.value
            event2.name = oldEvent.name + name
            newEvent = event2
        case let oldEvent as Event2:
            var event3 = Event3()
            event3.value = oldEvent.value
            event3.name = oldEvent.name + name
            newEvent = event3
        case let oldEvent as Event3:
            var event1 = Event1()
            event1.value = oldEvent.value
            event1.name = oldEvent.name + name
            newEvent = event1
        default:
            newEvent = event
        }

        next(newEvent, getState)
    }
}
