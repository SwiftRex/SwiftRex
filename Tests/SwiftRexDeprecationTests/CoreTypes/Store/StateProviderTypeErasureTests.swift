import Foundation
@testable import SwiftRex
import XCTest

class StateProviderTypeErasureTests: XCTestCase {
    func testStateProviderMockErased() {
        let mock = StateProviderMock<String>()
        mock.statePublisher = PublisherType<String, Never> { subscriber in
            subscriber.onValue("42")
            return FooSubscription()
        }

        let sut = mock.eraseToAnyStateProvider()

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("42", string)
            shouldCallClosure.fulfill()
        })

        _ = sut.statePublisher.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testStateProviderClosureErased() {
        let publisher = PublisherType<String, Never> { subscriber in
            subscriber.onValue("42")
            return FooSubscription()
        }
        let sut = AnyStateProvider(publisher)

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("42", string)
            shouldCallClosure.fulfill()
        })

        _ = sut.statePublisher.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testStateProviderMap() {
        let publisher = PublisherType<Int, Never> { subscriber in
            subscriber.onValue(42)
            return FooSubscription()
        }
        let sut = AnyStateProvider(publisher)

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("42", string)
            shouldCallClosure.fulfill()
        })

        _ = sut.map(String.init).statePublisher.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }
}
