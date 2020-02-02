import Foundation
@testable import SwiftRex
import XCTest

class StoreTypeTypeErasureTests: XCTestCase {
    func testActionHandlerMockErased() {
        let mock = StoreTypeMock<String, Never>()
        mock.underlyingStatePublisher = .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        let sut = mock.eraseToAnyStoreType()
        XCTAssertNil(mock.dispatchReceivedAction)
        sut.dispatch("1")
        XCTAssertEqual("1", mock.dispatchReceivedAction)
        mock.dispatch("2")
        XCTAssertEqual("2", mock.dispatchReceivedAction)
        mock.dispatch("3")
        XCTAssertEqual("3", mock.dispatchReceivedAction)
        sut.dispatch("4")
        XCTAssertEqual("4", mock.dispatchReceivedAction)
        sut.dispatch("5")
        XCTAssertEqual("5", mock.dispatchReceivedAction)

        XCTAssertEqual(5, mock.dispatchCallsCount)
    }

    func testActionHandlerClosureErased() {
        var actions: [String] = []
        let sut = AnyStoreType<String, Void>(
            action: { action in
                actions.append(action)
            },
            state: .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        )

        sut.dispatch("1")
        sut.dispatch("2")
        sut.dispatch("3")
        sut.dispatch("4")
        sut.dispatch("5")

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramap() {
        var actions: [String] = []
        let stringHandler = AnyStoreType<String, Never>(
            action: { action in
                actions.append(action)
            },
            state: .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        )
        let intHandler: AnyActionHandler<Int> = stringHandler.contramap { "\($0)" }

        intHandler.dispatch(1)
        intHandler.dispatch(2)
        intHandler.dispatch(3)
        intHandler.dispatch(4)
        intHandler.dispatch(5)

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramapAction() {
        var actions: [String] = []
        let publisher = PublisherType<Bool, Never> { subscriber in
            subscriber.onValue(true)
            return FooSubscription()
        }
        let stringHandler = AnyStoreType<String, Bool>(
            action: { action in
                actions.append(action)
            },
            state: publisher
        )
        let intHandler: AnyStoreType<Int, Bool> = stringHandler.contramapAction { "\($0)" }

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<Bool, Never>(onValue: { bool in
            XCTAssertTrue(bool)
            shouldCallClosure.fulfill()
        })
        _ = intHandler.statePublisher.subscribe(subscriberType)

        intHandler.dispatch(1)
        intHandler.dispatch(2)
        intHandler.dispatch(3)
        intHandler.dispatch(4)
        intHandler.dispatch(5)

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    ///

    func testStateProviderMockErased() {
        let mock = StoreTypeMock<Never, String>()
        mock.statePublisher = PublisherType<String, Never> { subscriber in
            subscriber.onValue("42")
            return FooSubscription()
        }

        let sut = mock.eraseToAnyStoreType()

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
        let sut = AnyStoreType<Never, String>(
            action: { _ in },
            state: publisher
        )

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
        let sut = AnyStoreType<Never, Int>(
            action: { _ in },
            state: publisher
        )

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("42", string)
            shouldCallClosure.fulfill()
        })

        let stringProvider: AnyStateProvider<String> = sut.map(String.init)
        _ = stringProvider.statePublisher.subscribe(subscriberType)

        wait(for: [shouldCallClosure], timeout: 0.1)
    }

    func testStateProviderMapState() {
        let publisher = PublisherType<Int, Never> { subscriber in
            subscriber.onValue(42)
            return FooSubscription()
        }
        let shouldCallAction = expectation(description: "Action should be called")
        let sut = AnyStoreType<Bool, Int>(
            action: { value in
                XCTAssertTrue(value)
                shouldCallAction.fulfill()
            },
            state: publisher
        )

        let shouldCallClosure = expectation(description: "Closure should be called")
        let subscriberType = SubscriberType<String, Never>(onValue: { string in
            XCTAssertEqual("42", string)
            shouldCallClosure.fulfill()
        })

        let stringProvider: AnyStoreType<Bool, String> = sut.mapState(String.init)
        _ = stringProvider.statePublisher.subscribe(subscriberType)
        stringProvider.dispatch(true)

        wait(for: [shouldCallClosure, shouldCallAction], timeout: 0.1)
    }
}
