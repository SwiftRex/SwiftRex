#if canImport(Combine)
@testable import SwiftRex
import XCTest

class MiddlewareTestsBase: XCTestCase {
    func lastActionInChain<A: ActionProtocol & Equatable>(_ action: A,
                                                          state: TestState,
                                                          expectation: XCTestExpectation)
        -> (ActionProtocol, @escaping GetState<TestState>) -> Void {
            return { chainAction, chainStateGetter in
                XCTAssertEqual(action, chainAction as! A)
                XCTAssertEqual(state, chainStateGetter())
                expectation.fulfill()
            }
    }

    func lastEventInChain<E: EventProtocol & Equatable>(_ event: E,
                                                        state: TestState,
                                                        expectation: XCTestExpectation)
        -> (EventProtocol, @escaping GetState<TestState>) -> Void {
            return { chainEvent, chainStateGetter in
                XCTAssertEqual(event, chainEvent as! E)
                XCTAssertEqual(state, chainStateGetter())
                expectation.fulfill()
            }
    }
}
#endif
