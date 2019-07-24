import Combine
import CombineRex
import SwiftRex
import XCTest

struct TestState: Equatable {
    var value = UUID()
    var name = "Initial State"
}

struct Event1: EventProtocol, Equatable {
    var value = UUID()
    var name = "e1"
}

struct Event2: EventProtocol, Equatable {
    var value = UUID()
    var name = "e2"
}

struct Action1: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a1"
    let event: Event1
}

struct Action2: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a2"
    let event: Event2
}

class MiddlewareTest: Middleware {
    var handlers: MessageHandler!

    func handle(event: EventProtocol, getState: @escaping () -> TestState, next: @escaping (EventProtocol, @escaping () -> TestState) -> Void) {
        if let event = event as? Event1 {
            handlers.actionHandler.trigger(Action1(event: event))
        } else if let event = event as? Event2 {
            handlers.actionHandler.trigger(Action2(event: event))
        }
        next(event, getState)
    }

    func handle(action: ActionProtocol,
                getState: @escaping () -> TestState,
                next: @escaping (ActionProtocol, @escaping () -> TestState) -> Void) {
        next(action, getState)
    }
}

class BindableStoreTests: XCTestCase {
    let reducerTest = Reducer<TestState> { state, action in
        if let action = action as? Action1 {
            return .init(value: UUID(), name: state.name + "_" + action.name)
        }

        if let action = action as? Action2 {
            return .init(value: UUID(), name: state.name + "_" + action.name)
        }

        return state
    }
    let middlewareTest = MiddlewareTest()
    var store: BindableStore<TestState>!

    override func setUp() {
        super.setUp()
        store = BindableStore<TestState>(initialState: TestState(), reducer: reducerTest, middleware: middlewareTest)
    }

    func testInitialState() {
        XCTAssertEqual("Initial State", store.state.name)
    }

    func testSubscribeDoNotTriggerWillChangeNotifyIntegrationTest() {
        let subscription = store.willChange.sink { _ in
            XCTFail("On subscribe this notification should never be triggered")
        }

        XCTAssertNotNil(subscription)
    }

    func testWillChangeNotifyOnChangeIntegrationTest() {
        let shouldBeNotifiedByWillChangePublisher = expectation(description: "should be notified by will change publisher")
        let subscription = store.willChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
            DispatchQueue.main.async {
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                shouldBeNotifiedByWillChangePublisher.fulfill()
            }
        }
        store.eventHandler.dispatch(Event1())

        wait(for: [shouldBeNotifiedByWillChangePublisher], timeout: 1)
        XCTAssertNotNil(subscription)
    }

    func testStatePublisherNotifyOnSubscribeIntegrationTest() {
        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by state publisher")
        let subscription = store.statePublisher.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
            shouldBeNotifiedByStatePublisher.fulfill()
        }

        wait(for: [shouldBeNotifiedByStatePublisher], timeout: 1)
        XCTAssertNotNil(subscription)
    }

    func testStatePublisherNotifyOnChangeIntegrationTest() {
        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by state publisher")
        var time = 0
        _ = store.statePublisher.sink { [unowned self] value in
            switch time {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
                XCTAssertEqual("Initial State", value.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                XCTAssertEqual("Initial State_a1", value.name)
                shouldBeNotifiedByStatePublisher.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time += 1
        }
        store.eventHandler.dispatch(Event1())

        wait(for: [shouldBeNotifiedByStatePublisher], timeout: 1)
    }

    func testWillChangePublisherCanHaveMultipleSubscriptions() {
        let shouldBeNotifiedByWillChangePublisher1 = expectation(description: "should be notified by will change publisher 1")
        let shouldBeNotifiedByWillChangePublisher2 = expectation(description: "should be notified by will change publisher 2")
        let subscription1 = store.willChange.sink { _ in
            XCTFail("On subscribe this notification should never be triggered")
        }
        subscription1.cancel()

        let subscription2 = store.willChange.sink { _ in
            XCTFail("On subscribe this notification should never be triggered")
        }
        subscription2.cancel()

        let subscription3 = store.willChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
            DispatchQueue.main.async {
                XCTAssertEqual("Initial State_a1", self.store.state.name)
            }
            shouldBeNotifiedByWillChangePublisher1.fulfill()
        }

        var time = 0
        let subscription4 = store.willChange.sink { [unowned self] _ in
            switch time {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
                DispatchQueue.main.async {
                    XCTAssertEqual("Initial State_a1", self.store.state.name)
                }
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                DispatchQueue.main.async {
                    XCTAssertEqual("Initial State_a1_a2", self.store.state.name)
                    shouldBeNotifiedByWillChangePublisher2.fulfill()
                }
            default:
                XCTFail("Too many calls")
            }
            time += 1
        }

        store.eventHandler.dispatch(Event1())

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            subscription3.cancel()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.store.eventHandler.dispatch(Event2())
        }

        wait(for: [shouldBeNotifiedByWillChangePublisher1, shouldBeNotifiedByWillChangePublisher2], timeout: 2)
        XCTAssertNotNil(subscription4)
    }

    func testStatePublisherCanHaveMultipleSubscriptions() {
        let shouldBeNotifiedByStatePublisher1 = expectation(description: "should be notified by state publisher")
        let shouldBeNotifiedByStatePublisher2 = expectation(description: "should be notified by state publisher")
        let subscription1 = store.statePublisher.sink { [unowned self] value in
            XCTAssertEqual("Initial State", self.store.state.name)
            XCTAssertEqual("Initial State", value.name)
        }
        subscription1.cancel()

        let subscription2 = store.statePublisher.sink { [unowned self] value in
            XCTAssertEqual("Initial State", self.store.state.name)
            XCTAssertEqual("Initial State", value.name)
        }
        subscription2.cancel()

        var time1 = 0
        let subscription3 = store.statePublisher.sink { [unowned self] value in
            switch time1 {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
                XCTAssertEqual("Initial State", value.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                XCTAssertEqual("Initial State_a1", value.name)
                shouldBeNotifiedByStatePublisher1.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time1 += 1
        }

        var time2 = 0
        let subscription4 = store.statePublisher.sink { [unowned self] value in
            switch time2 {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
                XCTAssertEqual("Initial State", value.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                XCTAssertEqual("Initial State_a1", value.name)
                shouldBeNotifiedByStatePublisher2.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time2 += 1
        }

        store.eventHandler.dispatch(Event1())

        wait(for: [shouldBeNotifiedByStatePublisher1, shouldBeNotifiedByStatePublisher2], timeout: 1)
        XCTAssertNotNil(subscription3)
        XCTAssertNotNil(subscription4)
    }
}
