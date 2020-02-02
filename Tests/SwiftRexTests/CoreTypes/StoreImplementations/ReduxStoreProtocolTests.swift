import Foundation
@testable import SwiftRex
import XCTest

class ReduxStoreProtocolTests: XCTestCase {
    func testDispatchIsForwardedToPipeline() {
        let sut = ReduxStoreProtocolMock<AppAction, TestState>()
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallActionHandler = expectation(description: "middleware action handler should have been called")
        let shouldCallActionHandlerAfterReducer =
            expectation(description: "middleware action handler after reducer should have been called")
        let shouldCallReducer = expectation(description: "reducer should have been called")
        middlewareMock.handleActionClosure = { action in
            XCTAssertEqual(action, expectedAction)
            shouldCallActionHandler.fulfill()
            return .do { shouldCallActionHandlerAfterReducer.fulfill() }
        }
        let reducer = createReducerMock()
        reducer.1.reduceClosure = { action, state in
            shouldCallReducer.fulfill()
            XCTAssertEqual(action, expectedAction)
            return state
        }
        let state = CurrentValueSubject(currentValue: TestState())
        sut.pipeline = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: state.subject!,
            reducer: reducer.0,
            middleware: middlewareMock)

        sut.dispatch(actionToDispatch)
        wait(for: [shouldCallActionHandler, shouldCallReducer, shouldCallActionHandlerAfterReducer], timeout: 0.1, enforceOrder: true)
    }
}
