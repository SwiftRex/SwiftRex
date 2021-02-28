import CombineX
import CombineXRex
import CXFoundation
import SwiftRex
import XCTest

class IssueTracker39Tests: XCTestCase {
    struct MyState: Equatable, Codable {
        enum ExecutionState: Int, Equatable, Codable {
            case stopped
            case requested
            case done
        }

        let preparation: ExecutionState
        let running: ExecutionState
    }

    enum MyEvent: Equatable {
        case requestPrepare
        case requestRun
    }

    enum MyAction: Equatable {
        case prepare
        case run
    }

    enum AppAction: Equatable {
        case events(MyEvent)
        case actions(MyAction)
    }

    class MyMiddleware: Middleware {
        var getState: (() -> MyState)!
        var output: AnyActionHandler<AppAction>!

        func receiveContext(getState: @escaping GetState<MyState>, output: AnyActionHandler<AppAction>) {
            self.getState = getState
            self.output = output
        }

        func handle(action: AppAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
            switch action {
            case .events(.requestPrepare):
                // Nothing asked yet
                XCTAssertEqual(getState().preparation, .stopped)
                XCTAssertEqual(getState().running, .stopped)

                afterReducer = .do { [unowned self] in
                    // After reducing "requestPrepare", preparation should have been requested
                    XCTAssertEqual(self.getState().preparation, .requested)
                    XCTAssertEqual(self.getState().running, .stopped)

                    self.output.dispatch(.actions(.prepare), from: .here())

                    // We expect the prepare action to happen only on the next runloop, so
                    // we still expect the state to remain unchanged
                    XCTAssertEqual(self.getState().preparation, .requested)
                    XCTAssertEqual(self.getState().running, .stopped)
                }

            case .events(.requestRun):
                // Because request run was called immediately after request preparation,
                // its execution will arrive at the store before "prepare" is ready, so it
                // was only requested
                XCTAssertEqual(getState().preparation, .requested)
                XCTAssertEqual(getState().running, .stopped)

                if getState().preparation == .done && getState().running == .requested {
                    output.dispatch(.actions(.run), from: .here())
                    // this should never happen, actually
                    XCTFail("This should never happen")
                }

                afterReducer = .do { [unowned self] in
                    // Both properties should be requested now, after reducing requestRun
                    XCTAssertEqual(self.getState().preparation, .requested)
                    XCTAssertEqual(self.getState().running, .requested)
                }
            case .actions(.prepare):
                // Prepare is done, but we haven't reduced this yet, so state should be preparation
                // requested. About running, it was requested before prepare was done, so both should
                // be at requested state by now
                XCTAssertEqual(getState().preparation, .requested)
                XCTAssertEqual(getState().running, .requested)

                afterReducer = .do { [unowned self] in
                    // After reducing "prepare", preparation should be done
                    XCTAssertEqual(self.getState().preparation, .done)
                    XCTAssertEqual(self.getState().running, .requested)

                    if self.getState().preparation == .done && self.getState().running == .requested {
                        // We evaluate this same condition in two places because we can reach the pre-conditions
                        // either when "preparation" or "running" states changed
                        // This time we are expected to execute this operation
                        self.output.dispatch(.actions(.run), from: .here())
                    }
                }
            case .actions(.run):
                // When we reach this point, preparation should be done and execution should have been
                // requested, but not reduced yet
                XCTAssertEqual(getState().preparation, .done)
                XCTAssertEqual(getState().running, .requested)

                afterReducer = .do { [unowned self] in
                    // Now everything should be done
                    XCTAssertEqual(self.getState().preparation, .done)
                    XCTAssertEqual(self.getState().running, .done)
                }
            }
        }
    }

    var middleware: MyMiddleware!
    var reducer: Reducer<AppAction, MyState>!
    var store: ReduxStoreBase<AppAction, MyState>!

    override func setUp() {
        super.setUp()
        middleware = MyMiddleware()

        reducer = Reducer<AppAction, MyState>.reduce { action, state in
            switch action {
            case .events(.requestPrepare):
                XCTAssertEqual(state.preparation, .stopped)
                XCTAssertEqual(state.running, .stopped)

                state = .init(preparation: .requested, running: state.running)
            case .events(.requestRun):
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .stopped)

                state = .init(preparation: state.preparation, running: .requested)
            case .actions(.prepare):
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .requested)

                state = .init(preparation: .done, running: state.running)
            case .actions(.run):
                XCTAssertEqual(state.preparation, .done)
                XCTAssertEqual(state.running, .requested)

                state = .init(preparation: state.preparation, running: .done)
            }
        }

        store = ReduxStoreBase(
            subject: .combineX(initialValue: MyState(preparation: .stopped, running: .stopped)),
            reducer: reducer,
            middleware: middleware
        )
    }

    func testIssue39() { // swiftlint:disable:this function_body_length
        let shouldBeNotifiedAboutInitialState = expectation(description: "should be notified about initial state")
        let shouldBeNotifiedAboutRequestedPrepare = expectation(description: "should be notified about requested prepare")
        let shouldBeNotifiedAboutPrepare = expectation(description: "should be notified about prepare")
        let shouldBeNotifiedAboutRequestedRun = expectation(description: "should be notified about requested run")
        let shouldBeNotifiedAboutRun = expectation(description: "should be notified about run")

        var count = 0
        let subscription = store.statePublisher.sink { state in
            switch count {
            case 0:
                XCTAssertEqual(state.preparation, .stopped)
                XCTAssertEqual(state.running, .stopped)
                shouldBeNotifiedAboutInitialState.fulfill()
            case 1:
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .stopped)
                shouldBeNotifiedAboutRequestedPrepare.fulfill()
            case 2:
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .requested)
                shouldBeNotifiedAboutRequestedRun.fulfill()
            case 3:
                XCTAssertEqual(state.preparation, .done)
                XCTAssertEqual(state.running, .requested)
                shouldBeNotifiedAboutPrepare.fulfill()
            case 4:
                XCTAssertEqual(state.preparation, .done)
                XCTAssertEqual(state.running, .done)
                shouldBeNotifiedAboutRun.fulfill()
            default:
                XCTFail("Unexpected notification")
            }
            count += 1
        }

        store.dispatch(.events(.requestPrepare), from: .here())
        store.dispatch(.events(.requestRun), from: .here())

        wait(
            for: [
                shouldBeNotifiedAboutInitialState,
                shouldBeNotifiedAboutRequestedPrepare,
                shouldBeNotifiedAboutRequestedRun,
                shouldBeNotifiedAboutPrepare,
                shouldBeNotifiedAboutRun
            ],
            timeout: 2,
            enforceOrder: true
        )

        XCTAssertNotNil(subscription)
    }
}
