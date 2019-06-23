import ReactiveSwift
import SwiftRex
import SwiftRexForRac
import XCTest

class SubjectTypeBridgeTests: XCTestCase {
    func testSignalToSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let (signal, input) = Signal<String, SomeError>.pipe()
        input.send(value: "no one cares")

        let sut = SubjectType(input: input, output: signal)

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

    func testSignalToSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let (signal, input) = Signal<String, SomeError>.pipe()
        input.send(value: "no one cares")

        let sut = SubjectType(input: input, output: signal)
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

        let sut = SubjectType<String, SomeError>.reactive()
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

        let sut = SubjectType<String, SomeError>.reactive()
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
