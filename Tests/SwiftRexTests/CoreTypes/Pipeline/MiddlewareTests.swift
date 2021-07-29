import Foundation
@testable import SwiftRex
import XCTest

class MiddlewareTests: XCTestCase {
    func testMiddlewareCallOrder() {
        let state = TestState()
        let receiveContextCalled = expectation(description: "receive context should be called")
        receiveContextCalled.expectedFulfillmentCount = 2
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

        sut.handle(action: .bar(.bravo), from: .here(), state: { state })
            .runIO(.init { _ in })

        sut.handle(action: .bar(.charlie), from: .here(), state: { state })
            .runIO(.init { _ in })

        wait(
            for: [
                actionBravoBeforeReducerCalled,
                actionBravoAfterReducerCalled,
                actionCharlieBeforeReducerCalled,
                actionCharlieAfterReducerCalled,
                receiveContextCalled
            ],
            timeout: 0.1,
            enforceOrder: true
        )
    }

    class SomeMiddleware: MiddlewareProtocol {
        typealias InputActionType = AppAction
        typealias OutputActionType = AppAction
        typealias StateType = TestState

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

        func handle(action: AppAction, from dispatcher: ActionSource, state: @escaping GetState<TestState>) -> IO<AppAction> {
            switch action {
            case .bar(.bravo): self.actionBravoBeforeReducerCalled.fulfill()
            case .bar(.charlie): self.actionCharlieBeforeReducerCalled.fulfill()
            default: XCTFail("Invalid action")
            }

            return IO { [unowned self] output in
                switch action {
                case .bar(.bravo): self.actionBravoAfterReducerCalled.fulfill()
                case .bar(.charlie): self.actionCharlieAfterReducerCalled.fulfill()
                default: XCTFail("Invalid action")
                }

                XCTAssertEqual(self.expectedId, state().value)
                self.receiveContextCalled.fulfill()
            }
        }
    }
}
