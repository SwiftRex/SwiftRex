import Nimble
import RxSwift
import RxSwiftRex
import SwiftRex
import XCTest

class SubjectTypeBridgeTests: XCTestCase {
    func testPublishSubjectToSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publishSubject = PublishSubject<String>()
        publishSubject.onNext("no one cares")

        let sut = SwiftRex.SubjectType(publishSubject: publishSubject)

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

    func testUnfailablePublishSubjectToSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let publishSubject = PublishSubject<String>()
        publishSubject.onNext("no one cares")

        let sut = SwiftRex.SubjectType(unfailablePublishSubject: publishSubject)

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

    func testPublishSubjectToSubjectTypeOnError() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureError = expectation(description: "Closure should be called")
        let someError = SomeError()

        let publishSubject = PublishSubject<String>()
        publishSubject.onNext("no one cares")

        let sut = SwiftRex.SubjectType(publishSubject: publishSubject)

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

                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }

    func testUnfailablePublishSubjectToSubjectTypeOnErrorCrashes() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")

        let publishSubject = PublishSubject<String>()
        publishSubject.onNext("no one cares")

        let sut = SwiftRex.SubjectType(unfailablePublishSubject: publishSubject)

        _ = sut.publisher.subscribe(SubscriberType(
            onValue: { string in
                XCTAssertEqual("test", string)
                shouldCallClosureValue.fulfill()
            },
            onCompleted: { _ in
                XCTFail("Unexpected completion")
            }))

        sut.subscriber.onValue("test")
        expect { publishSubject.onError(SomeError()) }.to(throwAssertion())
        sut.subscriber.onCompleted(nil)

        wait(for: [shouldCallClosureValue], timeout: 0.1)
    }

    func testDefaultSubjectTypeOnValue() {
        let shouldCallClosureValue = expectation(description: "Closure should be called")
        let shouldCallClosureCompleted = expectation(description: "Closure should be called")

        let sut = SwiftRex.SubjectType<String, SomeError>.rx()
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

        let sut = SwiftRex.SubjectType<String, SomeError>.rx()
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

                XCTAssertEqual(someError, error as! SomeError)
                shouldCallClosureError.fulfill()
            }))

        sut.subscriber.onValue("test")
        sut.subscriber.onCompleted(someError)

        wait(for: [shouldCallClosureValue, shouldCallClosureError], timeout: 0.1)
    }
}
