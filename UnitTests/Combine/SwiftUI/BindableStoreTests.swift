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

struct Action1: ActionProtocol, Equatable {
    var value = UUID()
    var name = "a1"
    let event: Event1
}

class MiddlewareTest: Middleware {
    var handlers: MessageHandler!

    func handle(event: EventProtocol, getState: @escaping () -> TestState, next: @escaping (EventProtocol, @escaping () -> TestState) -> Void) {
        if let event = event as? Event1 {
            handlers.actionHandler.trigger(Action1(event: event))
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
        guard let action = action as? Action1 else { return state }
        return .init(value: UUID(), name: state.name + "_" + action.name)
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

    func testDidChangeNotifyOnSubscribeIntegrationTest() {
        let shouldBeNotifiedByDidChangePublisher = expectation(description: "should be notified by did change publisher")
        _ = store.didChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
            shouldBeNotifiedByDidChangePublisher.fulfill()
        }

        wait(for: [shouldBeNotifiedByDidChangePublisher], timeout: 1)
    }

    func testDidChangeNotifyOnChangeIntegrationTest() {
        let shouldBeNotifiedByDidChangePublisher = expectation(description: "should be notified by did change publisher")
        var time = 0
        _ = store.didChange.sink { [unowned self] _ in
            switch time {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                shouldBeNotifiedByDidChangePublisher.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time += 1
        }
        store.eventHandler.dispatch(Event1())

        wait(for: [shouldBeNotifiedByDidChangePublisher], timeout: 1)
    }

    func testStatePublisherNotifyOnSubscribeIntegrationTest() {
        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by did change publisher")
        _ = store.didChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
            shouldBeNotifiedByStatePublisher.fulfill()
        }

        wait(for: [shouldBeNotifiedByStatePublisher], timeout: 1)
    }

    func testStatePublisherNotifyOnChangeIntegrationTest() {
        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by did change publisher")
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

    func testDidChangePublisherCanHaveMultipleSubscriptions() {
        let shouldBeNotifiedByDidChangePublisher1 = expectation(description: "should be notified by did change publisher")
        let shouldBeNotifiedByDidChangePublisher2 = expectation(description: "should be notified by did change publisher")
        let subscription1 = store.didChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
        }
        subscription1.cancel()

        let subscription2 = store.didChange.sink { [unowned self] _ in
            XCTAssertEqual("Initial State", self.store.state.name)
        }
        subscription2.cancel()

        var time1 = 0
        _ = store.didChange.sink { [unowned self] _ in
            switch time1 {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                shouldBeNotifiedByDidChangePublisher1.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time1 += 1
        }

        var time2 = 0
        _ = store.didChange.sink { [unowned self] _ in
            switch time2 {
            case 0:
                XCTAssertEqual("Initial State", self.store.state.name)
            case 1:
                XCTAssertEqual("Initial State_a1", self.store.state.name)
                shouldBeNotifiedByDidChangePublisher2.fulfill()
            default:
                XCTFail("Too many calls")
            }
            time2 += 1
        }

        store.eventHandler.dispatch(Event1())

        wait(for: [shouldBeNotifiedByDidChangePublisher1, shouldBeNotifiedByDidChangePublisher2], timeout: 1)
    }

    func testStatePublisherCanHaveMultipleSubscriptions() {
        let shouldBeNotifiedByStatePublisher1 = expectation(description: "should be notified by did change publisher")
        let shouldBeNotifiedByStatePublisher2 = expectation(description: "should be notified by did change publisher")
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
        _ = store.statePublisher.sink { [unowned self] value in
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
        _ = store.statePublisher.sink { [unowned self] value in
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
    }
}
