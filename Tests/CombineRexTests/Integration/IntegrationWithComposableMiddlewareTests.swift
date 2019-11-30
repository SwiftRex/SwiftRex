#if canImport(Combine)
import Combine
import CombineRex
import SwiftRex
import XCTest

class IntegrationWithComposableMiddlewareTests: XCTestCase {
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

    class MyEventsMiddleware: Middleware {
        var context: (() -> MiddlewareContext<AppAction, MyState>) = { fatalError("Middleware context not set") }

        func handle(action: AppAction, next: @escaping Next) {
            switch action {
            case .events(.requestPrepare):
                // Nothing asked yet
                XCTAssertEqual(context().getState().preparation, .stopped)
                XCTAssertEqual(context().getState().running, .stopped)

                next()

                // After reducing "requestPrepare", preparation should have been requested
                XCTAssertEqual(context().getState().preparation, .requested)
                XCTAssertEqual(context().getState().running, .stopped)

                context().dispatch(.actions(.prepare))

                // We expect the prepare action to happen only on the next runloop, so
                // we still expect the state to remain unchanged
                XCTAssertEqual(context().getState().preparation, .requested)
                XCTAssertEqual(context().getState().running, .stopped)

            case .events(.requestRun):
                // Because request run was called immediately after request preparation,
                // its execution will arrive at the store before "prepare" is ready, so it
                // was only requested
                XCTAssertEqual(context().getState().preparation, .requested)
                XCTAssertEqual(context().getState().running, .stopped)

                if context().getState().preparation == .done && context().getState().running == .requested {
                    context().dispatch(.actions(.run))
                    // this should never happen, actually
                    XCTFail("This should never happen")
                }

                next()

                // Both properties should be requested now, after reducing requestRun
                XCTAssertEqual(context().getState().preparation, .requested)
                XCTAssertEqual(context().getState().running, .requested)
            default:
                next()
            }
        }
    }

    class MyActionsMiddleware: Middleware {
        var context: (() -> MiddlewareContext<AppAction, MyState>) = { fatalError("Middleware context not set") }

        func handle(action: AppAction, next: @escaping Next) {
            switch action {
            case .actions(.prepare):
                // Prepare is done, but we haven't reduced this yet, so state should be preparation
                // requested. About running, it was requested before prepare was done, so both should
                // be at requested state by now
                XCTAssertEqual(context().getState().preparation, .requested)
                XCTAssertEqual(context().getState().running, .requested)

                next()

                // After reducing "prepare", preparation should be done
                XCTAssertEqual(context().getState().preparation, .done)
                XCTAssertEqual(context().getState().running, .requested)

                if context().getState().preparation == .done && context().getState().running == .requested {
                    // We evaluate this same condition in two places because we can reach the pre-conditions
                    // either when "preparation" or "running" states changed
                    // This time we are expected to execute this operation
                    context().dispatch(.actions(.run))
                }
            case .actions(.run):
                // When we reach this point, preparation should be done and execution should have been
                // requested, but not reduced yet
                XCTAssertEqual(context().getState().preparation, .done)
                XCTAssertEqual(context().getState().running, .requested)

                next()

                // Now everything should be done
                XCTAssertEqual(context().getState().preparation, .done)
                XCTAssertEqual(context().getState().running, .done)
            default:
                next()
            }
        }
    }

    var middleware: ComposedMiddleware<AppAction, AppAction, MyState>!
    var reducer: Reducer<AppAction, MyState>!
    var store: ReduxStoreBase<AppAction, MyState>!

    override func setUp() {
        super.setUp()
        middleware = MyEventsMiddleware() <> MyActionsMiddleware()

        reducer = Reducer<AppAction, MyState> { action, state in
            switch action {
            case .events(.requestPrepare):
                XCTAssertEqual(state.preparation, .stopped)
                XCTAssertEqual(state.running, .stopped)

                return .init(preparation: .requested, running: state.running)
            case .events(.requestRun):
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .stopped)

                return .init(preparation: state.preparation, running: .requested)
            case .actions(.prepare):
                XCTAssertEqual(state.preparation, .requested)
                XCTAssertEqual(state.running, .requested)

                return .init(preparation: .done, running: state.running)
            case .actions(.run):
                XCTAssertEqual(state.preparation, .done)
                XCTAssertEqual(state.running, .requested)

                return .init(preparation: state.preparation, running: .done)
            }
        }

        store = ReduxStoreBase(
            subject: .combine(initialValue: MyState(preparation: .stopped, running: .stopped)),
            reducer: reducer,
            middleware: middleware
        )
    }

    func testIssue39WithComposedMiddleware() { // swiftlint:disable:this function_body_length
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

        store.dispatch(.events(.requestPrepare))
        store.dispatch(.events(.requestRun))

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
#endif
