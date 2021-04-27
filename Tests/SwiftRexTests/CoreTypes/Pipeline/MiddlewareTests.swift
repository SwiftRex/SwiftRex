import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTests: XCTestCase {
    func testMiddlewareCallOrder() {
        let state = TestState()
        let receiveContextCalled = expectation(description: "receive context should be called")
        let actionBravoBeforeReducerCalled = expectation(description: "action bravo before reducer should be called")
        let actionCharlieBeforeReducerCalled = expectation(description: "action charlie before reducer should be called")
        let actionBravoAfterReducerCalled = expectation(description: "action bravo after reducer should be called")
        let actionCharlieAfterReducerCalled = expectation(description: "action charlie after reducer should be called")

        let sut = SomeMiddleware(
            expectedId: state.value,
            receiveContextCalled: receiveContextCalled,
            actionBravoBeforeReducerCalled: actionBravoBeforeReducerCalled,
            actionCharlieBeforeReducerCalled: actionCharlieBeforeReducerCalled,
            actionBravoAfterReducerCalled: actionBravoAfterReducerCalled,
            actionCharlieAfterReducerCalled: actionCharlieAfterReducerCalled
        )
        sut.receiveContext(getState: { state }, output: .init { _ in })

        var after1: AfterReducer = .doNothing()
        sut.handle(action: .bar(.bravo), from: .here(), afterReducer: &after1)
        after1.reducerIsDone()

        var after2: AfterReducer = .doNothing()
        sut.handle(action: .bar(.charlie), from: .here(), afterReducer: &after2)
        after2.reducerIsDone()

        wait(
            for: [
                receiveContextCalled,
                actionBravoBeforeReducerCalled,
                actionBravoAfterReducerCalled,
                actionCharlieBeforeReducerCalled,
                actionCharlieAfterReducerCalled
            ],
            timeout: 0.1,
            enforceOrder: true
        )
    }

    class SomeMiddleware: Middleware {
        let expectedId: UUID
        let receiveContextCalled: XCTestExpectation
        let actionBravoBeforeReducerCalled: XCTestExpectation
        let actionCharlieBeforeReducerCalled: XCTestExpectation
        let actionBravoAfterReducerCalled: XCTestExpectation
        let actionCharlieAfterReducerCalled: XCTestExpectation

        var getState: () -> TestState = { fatalError("get state was not supposed to be called") }
        var output: (AppAction) -> Void = { _ in fatalError("on action was not supposed to be called") }

        init(
            expectedId: UUID,
            receiveContextCalled: XCTestExpectation,
            actionBravoBeforeReducerCalled: XCTestExpectation,
            actionCharlieBeforeReducerCalled: XCTestExpectation,
            actionBravoAfterReducerCalled: XCTestExpectation,
            actionCharlieAfterReducerCalled: XCTestExpectation
        ) {
            self.expectedId = expectedId
            self.receiveContextCalled = receiveContextCalled
            self.actionBravoBeforeReducerCalled = actionBravoBeforeReducerCalled
            self.actionCharlieBeforeReducerCalled = actionCharlieBeforeReducerCalled
            self.actionBravoAfterReducerCalled = actionBravoAfterReducerCalled
            self.actionCharlieAfterReducerCalled = actionCharlieAfterReducerCalled
        }

        func receiveContext(getState: @escaping () -> TestState, output: AnyActionHandler<AppAction>) {
            XCTAssertEqual(expectedId, getState().value)
            self.receiveContextCalled.fulfill()
        }

        func handle(action: AppAction, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
            switch action {
            case .bar(.bravo): self.actionBravoBeforeReducerCalled.fulfill()
            case .bar(.charlie): self.actionCharlieBeforeReducerCalled.fulfill()
            default: XCTFail("Invalid action")
            }

            afterReducer = .do {
                switch action {
                case .bar(.bravo): self.actionBravoAfterReducerCalled.fulfill()
                case .bar(.charlie): self.actionCharlieAfterReducerCalled.fulfill()
                default: XCTFail("Invalid action")
                }
            }
        }
    }
}
