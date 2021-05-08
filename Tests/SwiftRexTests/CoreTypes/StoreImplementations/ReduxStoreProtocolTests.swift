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
        middlewareMock.handleActionFromAfterReducerClosure = { action, dispatcher, afterReducer in
            XCTAssertEqual(action, expectedAction)
            XCTAssertEqual("file_1", dispatcher.file)
            XCTAssertEqual("function_1", dispatcher.function)
            XCTAssertEqual(666, dispatcher.line)
            XCTAssertEqual("info_1", dispatcher.info)
            shouldCallActionHandler.fulfill()
            afterReducer = .do { shouldCallActionHandlerAfterReducer.fulfill() }
        }
        let reducer = createReducerMock()
        reducer.1.reduceClosure = { action, state in
            shouldCallReducer.fulfill()
            XCTAssertEqual(action, expectedAction)
            return state
        }
        let state = CurrentValueSubject(currentValue: TestState())
        sut.pipeline = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: { state.subject! },
            reducer: reducer.0,
            middleware: middlewareMock)

        sut.dispatch(actionToDispatch, from: .init(file: "file_1", function: "function_1", line: 666, info: "info_1"))
        wait(for: [shouldCallActionHandler, shouldCallReducer, shouldCallActionHandlerAfterReducer], timeout: 2, enforceOrder: true)
    }
}
