import Foundation
@testable import SwiftRex
import XCTest

class ReduxStoreProtocolTests: XCTestCase {
    func testDispatchIsForwardedToPipeline() {
        let sut = ReduxStoreProtocolMock<AppAction, TestState>()
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallMiddlewareActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionNextClosure = { action, _ in
            XCTAssertEqual(action, expectedAction)
            shouldCallMiddlewareActionHandler.fulfill()
        }
        sut.pipeline = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: CurrentValueSubject(currentValue: TestState()).subject!,
            reducer: createReducerMock().0,
            middleware: middlewareMock)

        sut.dispatch(actionToDispatch)

        wait(for: [shouldCallMiddlewareActionHandler], timeout: 0.1)
    }
}
