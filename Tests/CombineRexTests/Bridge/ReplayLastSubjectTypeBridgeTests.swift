import Combine
import CombineRex
import SwiftRex
import XCTest

class ReplayLastSubjectTypeBridgeTests: XCTestCase {
    func testCurrentValueSubjectToReplayLastSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let currentValueSubject = CurrentValueSubject<String, SomeError>("no one cares 1")
        currentValueSubject.value = "no one cares 2"
        currentValueSubject.value = "current value"

        let sut = ReplayLastSubjectType(currentValueSubject: currentValueSubject)

        var round = 1
        let subscription = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onValue("test")
        XCTAssertEqual(sut.value(), "test")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testCurrentValueSubjectToReplayLastSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")
        let shouldCallClosureCompletion = expectation(description: "Closure completion should be called")
        let someError = SomeError()
        let currentValueSubject = CurrentValueSubject<String, SomeError>("no one cares 1")
        currentValueSubject.value = "no one cares 2"
        currentValueSubject.value = "current value"

        let sut = ReplayLastSubjectType<String, SomeError>(currentValueSubject: currentValueSubject)

        let subscription = sut.publisher.subscribe(SubscriberType<String, SomeError>(
            onValue: { string in
                XCTAssertEqual("current value", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                // Different from other Reactive frameworks, Combine allows CurrentValueSubject to have an Error
                // generic parameter different than Never, which can receive error. However, it does never propagates
                // the error, finishing the stream successfully. It's not clear if this is a bug or it's by design,
                // the same way it's not clear whether or not these Subjects should complete at all. Anyway, this test
                // will be here to continuously observe this behaviour on Combine Framework and, eventually, adapt
                // SwiftRex behaviour to possible changes.
                // XCTAssertNil(error)

                // Update 08/July/2019: Yes, it was a bug. Will keep this comment here until the official release

                XCTAssertEqual(someError, error)

                shouldCallClosureCompletion.fulfill()
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompletion], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testCurrentValueSubjectToReplayLastSubjectTypeOnFinish() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")
        let shouldCallClosureCompletion = expectation(description: "Closure completion should be called")
        let currentValueSubject = CurrentValueSubject<String, SomeError>("no one cares 1")
        currentValueSubject.value = "no one cares 2"
        currentValueSubject.value = "current value"

        let sut = ReplayLastSubjectType<String, SomeError>(currentValueSubject: currentValueSubject)

        let subscription = sut.publisher.subscribe(SubscriberType<String, SomeError>(
            onValue: { string in
                XCTAssertEqual("current value", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { error in
                XCTAssertNil(error)
                shouldCallClosureCompletion.fulfill()
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue, shouldCallClosureCompletion], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testDefaultReplayLastSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let sut = ReplayLastSubjectType<String, SomeError>.combine(initialValue: "no one cares 1")
        sut.subscriber.onValue("no one cares 2")
        sut.subscriber.onValue("current value")

        var round = 1
        let subscription = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")
        sut.subscriber.onValue("test")
        XCTAssertEqual(sut.value(), "test")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }

    func testDefaultReplayLastSubjectTypeMutate() {
        let shouldCallClosureValue = expectation(description: "Closure value should be called")

        let sut = ReplayLastSubjectType<String, SomeError>.combine(initialValue: "no one cares 1")
        sut.subscriber.onValue("no one cares 2")
        sut.subscriber.onValue("current value")

        var round = 1
        let subscription = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                switch round {
                case 1:
                    XCTAssertEqual("current value", string)
                case 2:
                    XCTAssertEqual("test", string)
                case 3:
                    XCTAssertEqual("test 2", string)
                    shouldCallClosureValue.fulfill()
                default:
                    XCTFail("called too many times")
                }
                round += 1
            }
        ))

        XCTAssertEqual(sut.value(), "current value")

        sut.mutate { value in
            XCTAssertEqual("current value", value)
            value = "test"
        }
        XCTAssertEqual(sut.value(), "test")

        sut.mutate { value in
            XCTAssertEqual("test", value)
            value = "test 2"
        }
        XCTAssertEqual(sut.value(), "test 2")

        wait(for: [shouldCallClosureValue], timeout: 0.1)
        XCTAssertNotNil(subscription)
    }
}
