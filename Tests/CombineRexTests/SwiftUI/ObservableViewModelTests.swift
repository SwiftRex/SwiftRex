#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

struct TestState: Equatable {
    var value = UUID()
    var name = "Initial State"
}

enum Event: Equatable {
    case event1(Event1)
    case event2(Event2)
}

struct Event1: Equatable {
    var value = UUID()
    var name = "e1"
}

struct Event2: Equatable {
    var value = UUID()
    var name = "e2"
}

indirect enum Action: Equatable {
    case action1(Action1)
    case action2(Action2)
    case middlewareAction(Action)
    case middlewareActionAfterReducer(Action)

    var name: String {
        switch self {
        case let .action1(action): return action.name
        case let .action2(action): return action.name
        case let .middlewareAction(action): return action.name
        case let .middlewareActionAfterReducer(action): return action.name
        }
    }
}

struct Action1: Equatable {
    var value = UUID()
    var name = "a1"
    let event: Event1
}

struct Action2: Equatable {
    var value = UUID()
    var name = "a2"
    let event: Event2
}

class MiddlewareTest: Middleware {
    var getState: (() -> TestState)?
    var output: AnyActionHandler<Action>?

    func receiveContext(getState: @escaping GetState<TestState>, output: AnyActionHandler<Action>) {
        self.getState = getState
        self.output = output
    }

    func handle(action: Action) -> AfterReducer {
        switch action {
        case .middlewareAction, .middlewareActionAfterReducer:
            return .doNothing()
        default:
            break
        }

        output?.dispatch(.middlewareAction(action))
        return AfterReducer.do {
            self.output?.dispatch(.middlewareActionAfterReducer(action))
        }
    }
}

class ObservableViewModelTests: XCTestCase {
    let reducerTest = Reducer<Action, TestState> { action, state in
        switch action {
        case let .action1(action):
            return .init(value: UUID(), name: state.name + "_" + action.name)
        case let .action2(action):
            return .init(value: UUID(), name: state.name + "_" + action.name)
        case let .middlewareAction(action):
            return .init(value: UUID(), name: state.name + "_ma:" + action.name)
        case let .middlewareActionAfterReducer(action):
            return .init(value: UUID(), name: state.name + "_maar:" + action.name)
        }
    }
    var statePublisher: CurrentValueSubject<TestState, Never>!
    let middlewareTest = MiddlewareTest()
    var viewModel: ObservableViewModel<Event, String>!

    override func setUp() {
        super.setUp()

        statePublisher = .init(TestState())
        viewModel = ReduxStoreBase(
            subject: .init(currentValueSubject: statePublisher),
            reducer: reducerTest,
            middleware: middlewareTest,
            emitsValue: .whenDifferent
        ).projection(
            action: { event in
                switch event {
                case let .event1(event1): return Action.action1(.init(event: event1))
                case let .event2(event2): return Action.action2(.init(event: event2))
                }
            },
            state: { (state: TestState) -> String in
                "name: \(state.name)"
            }
        ).asObservableViewModel(initialState: "")
    }

    func testInitialState() {
        XCTAssertEqual("name: Initial State", viewModel.state)
    }

    func testSubscribeDoNotTriggerWillChangeNotifyIntegrationTest() {
        let subscription = viewModel.objectWillChange.sink { _ in
            XCTFail("On subscribe this notification should never be triggered")
        }

        XCTAssertNotNil(subscription)
    }

    func testWillChangeNotifyOnChangeIntegrationTest() {
        let shouldBeNotifiedByWillChangePublisher = expectation(description: "should be notified by will change publisher")
        var count = 0
        let subscription = viewModel.objectWillChange.sink { [unowned self] _ in
            print("count: \(count) value: \(self.viewModel.state)")
            switch count {
            case 0:
                XCTAssertEqual("name: Initial State", self.viewModel.state)
            case 1:
                XCTAssertEqual("name: Initial State_a1", self.viewModel.state)
            case 2:
                XCTAssertEqual("name: Initial State_a1_ma:a1", self.viewModel.state)
            case 3:
                XCTAssertEqual("name: Initial State_a1_ma:a1_maar:a1", self.viewModel.state)
                shouldBeNotifiedByWillChangePublisher.fulfill()
            default:
                XCTFail("Unexpected notification: \(self.viewModel.state)")
            }
            count += 1
        }
        viewModel.dispatch(.event1(Event1()))

        wait(for: [shouldBeNotifiedByWillChangePublisher], timeout: 1)
        XCTAssertNotNil(subscription)
    }

//    func testStatePublisherNotifyOnSubscribeIntegrationTest() {
//        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by state publisher")
//        let subscription = store.statePublisher.sink { [unowned self] _ in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            shouldBeNotifiedByStatePublisher.fulfill()
//        }
//
//        wait(for: [shouldBeNotifiedByStatePublisher], timeout: 1)
//        XCTAssertNotNil(subscription)
//    }
//
//    func testStatePublisherNotifyOnChangeIntegrationTest() {
//        let shouldBeNotifiedByStatePublisher = expectation(description: "should be notified by state publisher")
//        var time = 0
//        let cancellable = store.statePublisher.sink { [unowned self] value in
//            switch time {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                XCTAssertEqual("Initial State", value.name)
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                XCTAssertEqual("Initial State_a1", value.name)
//                shouldBeNotifiedByStatePublisher.fulfill()
//            default:
//                XCTFail("Too many calls")
//            }
//            time += 1
//        }
//        store.eventHandler.dispatch(Event1())
//
//        wait(for: [shouldBeNotifiedByStatePublisher], timeout: 1)
//        XCTAssertNotNil(cancellable)
//    }

//    func testWillChangePublisherCanHaveMultipleSubscriptions() {
//        let shouldBeNotifiedByWillChangePublisher1 = expectation(description: "should be notified by will change publisher 1")
//        let shouldBeNotifiedByWillChangePublisher2 = expectation(description: "should be notified by will change publisher 2")
//        let subscription1 = store.objectWillChange.sink { _ in
//            XCTFail("On subscribe this notification should never be triggered")
//        }
//        subscription1.cancel()
//
//        let subscription2 = store.objectWillChange.sink { _ in
//            XCTFail("On subscribe this notification should never be triggered")
//        }
//        subscription2.cancel()
//
//        let subscription3 = store.objectWillChange.sink { [unowned self] _ in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            DispatchQueue.main.async {
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//            }
//            shouldBeNotifiedByWillChangePublisher1.fulfill()
//        }
//
//        var time = 0
//        let subscription4 = store.objectWillChange.sink { [unowned self] _ in
//            switch time {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                DispatchQueue.main.async {
//                    XCTAssertEqual("Initial State_a1", self.store.state.name)
//                }
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                DispatchQueue.main.async {
//                    XCTAssertEqual("Initial State_a1_a2", self.store.state.name)
//                    shouldBeNotifiedByWillChangePublisher2.fulfill()
//                }
//            default:
//                XCTFail("Too many calls")
//            }
//            time += 1
//        }
//
//        store.eventHandler.dispatch(Event1())
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//            subscription3.cancel()
//        }
//
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
//            self.store.eventHandler.dispatch(Event2())
//        }
//
//        wait(for: [shouldBeNotifiedByWillChangePublisher1, shouldBeNotifiedByWillChangePublisher2], timeout: 2)
//        XCTAssertNotNil(subscription4)
//    }
//
//    func testStatePublisherCanHaveMultipleSubscriptions() {
//        let shouldBeNotifiedByStatePublisher1 = expectation(description: "should be notified by state publisher")
//        let shouldBeNotifiedByStatePublisher2 = expectation(description: "should be notified by state publisher")
//        let subscription1 = store.statePublisher.sink { [unowned self] value in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            XCTAssertEqual("Initial State", value.name)
//        }
//        subscription1.cancel()
//
//        let subscription2 = store.statePublisher.sink { [unowned self] value in
//            XCTAssertEqual("Initial State", self.store.state.name)
//            XCTAssertEqual("Initial State", value.name)
//        }
//        subscription2.cancel()
//
//        var time1 = 0
//        let subscription3 = store.statePublisher.sink { [unowned self] value in
//            switch time1 {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                XCTAssertEqual("Initial State", value.name)
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                XCTAssertEqual("Initial State_a1", value.name)
//                shouldBeNotifiedByStatePublisher1.fulfill()
//            default:
//                XCTFail("Too many calls")
//            }
//            time1 += 1
//        }
//
//        var time2 = 0
//        let subscription4 = store.statePublisher.sink { [unowned self] value in
//            switch time2 {
//            case 0:
//                XCTAssertEqual("Initial State", self.store.state.name)
//                XCTAssertEqual("Initial State", value.name)
//            case 1:
//                XCTAssertEqual("Initial State_a1", self.store.state.name)
//                XCTAssertEqual("Initial State_a1", value.name)
//                shouldBeNotifiedByStatePublisher2.fulfill()
//            default:
//                XCTFail("Too many calls")
//            }
//            time2 += 1
//        }
//
//        store.eventHandler.dispatch(Event1())
//
//        wait(for: [shouldBeNotifiedByStatePublisher1, shouldBeNotifiedByStatePublisher2], timeout: 1)
//        XCTAssertNotNil(subscription3)
//        XCTAssertNotNil(subscription4)
//    }
}
#endif
