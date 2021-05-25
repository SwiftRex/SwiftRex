@testable import SwiftRex
import XCTest

class AfterReducerTests: XCTestCase {
    func testIdentity() {
        // Given
        let sut = AfterReducer.identity

        // Then
        sut.reducerIsDone()
    }

    func testDoSomething() {
        // Given
        let shouldDoSomething = expectation(description: "should have done something")
        let sut = AfterReducer.do { shouldDoSomething.fulfill() }

        // When
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething], timeout: 0.1)
    }

    func testMonoidTwo() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let afterReducer1 = AfterReducer.do { shouldDoSomething1.fulfill() }
        let afterReducer2 = AfterReducer.do { shouldDoSomething2.fulfill() }

        // When
        let sut = afterReducer1 <> afterReducer2
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething2, shouldDoSomething1], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidThree() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let afterReducer1 = AfterReducer.do { shouldDoSomething1.fulfill() }
        let afterReducer2 = AfterReducer.do { shouldDoSomething2.fulfill() }
        let afterReducer3 = AfterReducer.do { shouldDoSomething3.fulfill() }

        // When
        let sut = afterReducer1 <> afterReducer2 <> afterReducer3
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething3, shouldDoSomething2, shouldDoSomething1], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidFour() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let shouldDoSomething4 = expectation(description: "should have done something 4")
        let afterReducer1 = AfterReducer.do { shouldDoSomething1.fulfill() }
        let afterReducer2 = AfterReducer.do { shouldDoSomething2.fulfill() }
        let afterReducer3 = AfterReducer.do { shouldDoSomething3.fulfill() }
        let afterReducer4 = AfterReducer.do { shouldDoSomething4.fulfill() }

        // When
        let composition1 = afterReducer1 <> afterReducer2
        let composition2 = afterReducer3 <> afterReducer4
        let sut = composition1 <> composition2
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething4, shouldDoSomething3, shouldDoSomething2, shouldDoSomething1], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidFourWithIdentities() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let shouldDoSomething4 = expectation(description: "should have done something 4")
        let afterReducer1 = AfterReducer.do { shouldDoSomething1.fulfill() }
        let afterReducer2 = AfterReducer.do { shouldDoSomething2.fulfill() }
        let afterReducer3 = AfterReducer.do { shouldDoSomething3.fulfill() }
        let afterReducer4 = AfterReducer.do { shouldDoSomething4.fulfill() }

        // When
        let composition1 = afterReducer1 <> AfterReducer.identity <> afterReducer2
        let composition2 = AfterReducer.identity <> afterReducer3 <> afterReducer4 <> AfterReducer.identity
        let sut = composition1 <> AfterReducer.identity <> composition2 <> AfterReducer.identity
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething4, shouldDoSomething3, shouldDoSomething2, shouldDoSomething1], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidArray() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let shouldDoSomething4 = expectation(description: "should have done something 4")
        let afterReducer1 = AfterReducer.do { shouldDoSomething1.fulfill() }
        let afterReducer2 = AfterReducer.do { shouldDoSomething2.fulfill() }
        let afterReducer3 = AfterReducer.do { shouldDoSomething3.fulfill() }
        let afterReducer4 = AfterReducer.do { shouldDoSomething4.fulfill() }

        // When
        let array = [afterReducer1, afterReducer2, afterReducer3, afterReducer4]
        let sut = array.asAfterReducer()
        sut.reducerIsDone()

        // Then
        wait(for: [shouldDoSomething4, shouldDoSomething3, shouldDoSomething2, shouldDoSomething1], timeout: 0.1, enforceOrder: true)
    }
}
