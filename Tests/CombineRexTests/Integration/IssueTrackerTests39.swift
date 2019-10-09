#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

class IssueTracker39Tests: XCTestCase {
    struct MyState: Equatable, Codable {
        var isPrepared: Bool
        var isRunning: Bool
    }

    enum MyEvent: EventProtocol, Equatable {
        case requestPrepare
        case requestRun
    }

    enum MyAction: ActionProtocol, Equatable {
        case prepare
        case run
    }

    class MyMiddleware: Middleware {
        var handlers: MessageHandler!

        func handle(event: EventProtocol, getState: @escaping GetState<MyState>, next: @escaping NextEventHandler<MyState>) {
            next(event, getState)

            switch event as? MyEvent {
            case .requestPrepare?:
                XCTAssertFalse(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

                handlers.actionHandler.trigger(MyAction.prepare)

                XCTAssertTrue(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

            case .requestRun?:
                XCTAssertTrue(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

                handlers.actionHandler.trigger(MyAction.run)

                XCTAssertTrue(getState().isPrepared)
                XCTAssertTrue(getState().isRunning)

            default:
                XCTFail("Unexpected event")
            }
        }

        func handle(action: ActionProtocol, getState: @escaping GetState<MyState>, next: @escaping NextActionHandler<MyState>) {
            // Before reducing
            switch action as? MyAction {
            case .prepare?:
                XCTAssertFalse(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

            case .run?:
                XCTAssertTrue(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

            default:
                XCTFail("Unexpected action")
            }

            next(action, getState)

            // After reducing
            switch action as? MyAction {
            case .prepare?:
                XCTAssertTrue(getState().isPrepared)
                XCTAssertFalse(getState().isRunning)

            case .run?:
                XCTAssertTrue(getState().isPrepared)
                XCTAssertTrue(getState().isRunning)

            default:
                XCTFail("Unexpected action")
            }
        }
    }

    var middleware: MyMiddleware!
    var reducer: Reducer<MyState>!
    var store: StoreBase<MyState>!

    override func setUp() {
        super.setUp()
        middleware = MyMiddleware()

        reducer = Reducer<MyState> { state, action in
            switch action as? MyAction {
            case .prepare?:
                XCTAssertFalse(state.isPrepared)
                XCTAssertFalse(state.isRunning)
                return .init(isPrepared: true, isRunning: false)
            case .run?:
                XCTAssertTrue(state.isPrepared)
                XCTAssertFalse(state.isRunning)
                return .init(isPrepared: true, isRunning: true)
            default:
                XCTFail("Unexpected action")
            }
            return state
        }

        store = StoreBase(
            subject: .combine(initialValue: MyState(isPrepared: false, isRunning: false)),
            reducer: reducer,
            middleware: middleware
        )
    }

    func testIssue39() {
        let shouldBeNotifiedAboutInitialState = expectation(description: "should be notified about initial state")
        let shouldBeNotifiedAboutPrepare = expectation(description: "should be notified about prepare")
        let shouldBeNotifiedAboutRun = expectation(description: "should be notified about run")

        var count = 0
        let subscription = store.statePublisher.sink { state in
            switch count {
            case 0:
                XCTAssertFalse(state.isPrepared)
                XCTAssertFalse(state.isRunning)
                shouldBeNotifiedAboutInitialState.fulfill()
            case 1:
                XCTAssertTrue(state.isPrepared)
                XCTAssertFalse(state.isRunning)
                shouldBeNotifiedAboutPrepare.fulfill()
            case 2:
                XCTAssertTrue(state.isPrepared)
                XCTAssertTrue(state.isRunning)
                shouldBeNotifiedAboutRun.fulfill()
            default:
                XCTFail("Unexpected notification")
            }
            count += 1
        }

        store.eventHandler.dispatch(MyEvent.requestPrepare)
        store.eventHandler.dispatch(MyEvent.requestRun)

        wait(for: [shouldBeNotifiedAboutInitialState, shouldBeNotifiedAboutPrepare, shouldBeNotifiedAboutRun], timeout: 2)
        XCTAssertNotNil(subscription)
    }
}
#endif
