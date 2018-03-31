@testable import SwiftRex
import XCTest

struct TestState: Equatable {
    var value = UUID()
    var name = ""
}

struct Action1: Action, Equatable {
    var value = UUID()
    var name = "a1"
}

struct Action2: Action, Equatable {
    var value = UUID()
    var name = "a2"
}

struct Action3: Action, Equatable {
    var value = UUID()
    var name = "a3"
}

struct Event1: Event, Equatable {
    var value = UUID()
    var name = "e1"
}

struct Event2: Event, Equatable {
    var value = UUID()
    var name = "e2"
}

struct Event3: Event, Equatable {
    var value = UUID()
    var name = "e3"
}

extension ReducerMock {
    typealias StateType = TestState
}

extension MiddlewareMock {
    typealias StateType = TestState
}

class RotationMiddleware: Middleware {
    private var name: String

    init(name: String) {
        self.name = name
    }

    func handle(action: Action, getState: @escaping GetState<TestState>, next: @escaping (Action, @escaping GetState<TestState>) -> Void) {
        let newAction: Action
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

    func handle(event: Event, getState: @escaping GetState<TestState>, next: @escaping (Event, @escaping GetState<TestState>) -> Void) {
        let newEvent: Event
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

struct NameReducer: Reducer {
    func reduce(_ currentState: TestState, action: Action) -> TestState {
        switch action {
        case _ as Action1:
            var state = currentState
            state.name = "action1"
            return state
        case _ as Action2:
            var state = currentState
            state.name = "action2"
            return state
        default: return currentState
        }
    }
}

class TestStore: StoreBase<TestState> {
}
