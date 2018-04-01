@testable import SwiftRex
import XCTest

class MiddlewareTestsBase: XCTestCase {

    func lastActionInChain<A: Action & Equatable>(_ action: A,
                                                  state: TestState,
                                                  expectation: XCTestExpectation)
        -> (Action, @escaping GetState<TestState>) -> Void {
            return { chainAction, chainStateGetter in
                XCTAssertEqual(action, chainAction as! A)
                XCTAssertEqual(state, chainStateGetter())
                expectation.fulfill()
            }
    }

    func lastEventInChain<E: Event & Equatable>(_ event: E,
                                                state: TestState,
                                                expectation: XCTestExpectation)
        -> (Event, @escaping GetState<TestState>) -> Void {
            return { chainEvent, chainStateGetter in
                XCTAssertEqual(event, chainEvent as! E)
                XCTAssertEqual(state, chainStateGetter())
                expectation.fulfill()
            }
    }
}
