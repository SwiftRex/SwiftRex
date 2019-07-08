import Combine
import CombineRex
import SwiftRex
import XCTest

class SubjectTypeBridgeTests: XCTestCase {
    func testPassthroughSubjectToSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let passthroughSubject = PassthroughSubject<String, SomeError>()
        passthroughSubject.send("no one cares")

        let sut = SubjectType(passthroughSubject: passthroughSubject)

        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                if let error = error {
                    XCTFail("Unexpected error: \(error)")
                }
                shouldCallClosureCompleted.fulfill()
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testPassthroughSubjectToSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let passthroughSubject = PassthroughSubject<String, SomeError>()
        passthroughSubject.send("no one cares")

        let sut = SubjectType(passthroughSubject: passthroughSubject)

        _ = sut.publisher.subscribe(SubscriberType(
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
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testDefaultSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let sut = SubjectType<String, SomeError>.combine()
        sut.subscriber.onValue("no one cares")

        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                if let error = error {
                    XCTFail("Unexpected error: \(error)")
                }
                shouldCallClosureCompleted.fulfill()
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompleted], timeout: 0.1)
    }

    func testDefaultSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let sut = SubjectType<String, SomeError>.combine()
        sut.subscriber.onValue("no one cares")

        _ = sut.publisher.subscribe(SubscriberType(
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
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
