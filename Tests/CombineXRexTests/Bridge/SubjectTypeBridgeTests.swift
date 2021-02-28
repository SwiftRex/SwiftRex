import CombineX
import CombineXRex
import CXFoundation
import SwiftRex
import XCTest

class SubjectTypeBridgeTests: XCTestCase {
    func testPassthroughSubjectToSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure completion should be called")

        let passthroughSubject = PassthroughSubject<String, SomeError>()
        passthroughSubject.send("initial value will not be notified (no replay)")

        let sut = SubjectType(passthroughSubject: passthroughSubject)

        let subscription = sut.publisher.subscribe(.combineX(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                if let error = error {
                    XCTFail("Unexpected error: \(error)")
                }
                shouldCallClosureCompleted.fulfill()
            }
        ))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testPassthroughSubjectToSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let passthroughSubject = PassthroughSubject<String, SomeError>()
        passthroughSubject.send("no one cares")

        let sut = SubjectType(passthroughSubject: passthroughSubject)

        let subscription = sut.publisher.subscribe(.combineX(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                guard let error = error else {
                    XCTFail("Unexpected completion")
                    return
                }

                XCTAssertEqual(someError, error)
                shouldCallClosureError.fulfill()
            }
        ))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testDefaultSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let sut = SubjectType<String, SomeError>.combineX()
        sut.subscriber.onValue("no one cares")

        let subscription = sut.publisher.subscribe(.combineX(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                if let error = error {
                    XCTFail("Unexpected error: \(error)")
                }
                shouldCallClosureCompleted.fulfill()
            }
        ))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testDefaultSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let sut = SubjectType<String, SomeError>.combineX()
        sut.subscriber.onValue("no one cares")

        let subscription = sut.publisher.subscribe(.combineX(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                guard let error = error else {
                    XCTFail("Unexpected completion")
                    return
                }

                XCTAssertEqual(someError, error)
                shouldCallClosureError.fulfill()
            }
        ))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }
}
