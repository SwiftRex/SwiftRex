@testable import SwiftRex
import XCTest

class IOTests: XCTestCase {
    func testIdentity() {
        // Given
        let sut = IO<String>.identity

        // Then
        sut.run(.init { _ in XCTFail("Should not receive actions") })
    }

    func testPure() {
        // Given
        let sut = IO<String>.pure()

        // Then
        sut.run(.init { _ in XCTFail("Should not receive actions") })
    }

    func testDoSomething() {
        // Given
        let shouldDoSomething = expectation(description: "should have done something")
        let shouldReceiveValue = expectation(description: "should have received something")
        let sut = IO<String> { output in
            output.dispatch("42")
            shouldDoSomething.fulfill()
        }

        // When
        sut.run(.init { value in
            XCTAssertEqual(value.action, "42")
            shouldReceiveValue.fulfill()
        })

        // Then
        wait(for: [shouldDoSomething, shouldReceiveValue], timeout: 0.1)
    }

    func testMonoidTwo() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldReceiveValue1 = expectation(description: "should have received something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldReceiveValue2 = expectation(description: "should have received something 2")
        let afterReducer1 = IO<String> { output in
            output.dispatch("1")
            shouldDoSomething1.fulfill()
        }
        let afterReducer2 = IO<String> { output in
            output.dispatch("2")
            shouldDoSomething2.fulfill()
        }

        // When
        let sut = afterReducer1 <> afterReducer2
        sut.run(.init { value in
            switch value.action {
            case "1": shouldReceiveValue1.fulfill()
            case "2": shouldReceiveValue2.fulfill()
            default: XCTFail("Received wrong action")
            }
        })

        // Then
        wait(for: [shouldReceiveValue1, shouldDoSomething1, shouldReceiveValue2, shouldDoSomething2], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidThree() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let afterReducer1 = IO<String> { _ in shouldDoSomething1.fulfill() }
        let afterReducer2 = IO<String> { _ in shouldDoSomething2.fulfill() }
        let afterReducer3 = IO<String> { _ in shouldDoSomething3.fulfill() }

        // When
        let sut = afterReducer1 <> afterReducer2 <> afterReducer3
        sut.run(.init { _ in XCTFail("Should not receive actions") })

        // Then
        wait(for: [shouldDoSomething1, shouldDoSomething2, shouldDoSomething3], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidFour() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let shouldDoSomething4 = expectation(description: "should have done something 4")
        let afterReducer1 = IO<String> { _ in shouldDoSomething1.fulfill() }
        let afterReducer2 = IO<String> { _ in shouldDoSomething2.fulfill() }
        let afterReducer3 = IO<String> { _ in shouldDoSomething3.fulfill() }
        let afterReducer4 = IO<String> { _ in shouldDoSomething4.fulfill() }

        // When
        let composition1 = afterReducer1 <> afterReducer2
        let composition2 = afterReducer3 <> afterReducer4
        let sut = composition1 <> composition2
        sut.run(.init { _ in XCTFail("Should not receive actions") })

        // Then
        wait(for: [shouldDoSomething1, shouldDoSomething2, shouldDoSomething3, shouldDoSomething4], timeout: 0.1, enforceOrder: true)
    }

    func testMonoidFourWithIdentities() {
        // Given
        let shouldDoSomething1 = expectation(description: "should have done something 1")
        let shouldDoSomething2 = expectation(description: "should have done something 2")
        let shouldDoSomething3 = expectation(description: "should have done something 3")
        let shouldDoSomething4 = expectation(description: "should have done something 4")
        let afterReducer1 = IO<String> { _ in shouldDoSomething1.fulfill() }
        let afterReducer2 = IO<String> { _ in shouldDoSomething2.fulfill() }
        let afterReducer3 = IO<String> { _ in shouldDoSomething3.fulfill() }
        let afterReducer4 = IO<String> { _ in shouldDoSomething4.fulfill() }

        // When
        let composition1 = afterReducer1 <> IO<String>.identity <> afterReducer2
        let composition2 = IO<String>.identity <> afterReducer3 <> afterReducer4 <> IO<String>.identity
        let sut = composition1 <> IO<String>.identity <> composition2 <> IO<String>.identity
        sut.run(.init { _ in XCTFail("Should not receive actions") })

        // Then
        wait(for: [shouldDoSomething1, shouldDoSomething2, shouldDoSomething3, shouldDoSomething4], timeout: 0.1, enforceOrder: true)
    }
}
