import Foundation
@testable import SwiftRex
import XCTest

class StoreTypeTypeErasureTests: XCTestCase {
    func testActionHandlerMockErased() {
        let mock = StoreTypeMock<String, Never>()
        mock.underlyingStatePublisher = .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        let sut = mock.eraseToAnyStoreType()
        XCTAssertNil(mock.dispatchReceivedDispatchedAction?.action)
        sut.dispatch("1", from: .here())
        XCTAssertEqual("1", mock.dispatchReceivedDispatchedAction?.action)
        mock.dispatch("2", from: .here())
        XCTAssertEqual("2", mock.dispatchReceivedDispatchedAction?.action)
        mock.dispatch("3", from: .here())
        XCTAssertEqual("3", mock.dispatchReceivedDispatchedAction?.action)
        sut.dispatch("4", from: .here())
        XCTAssertEqual("4", mock.dispatchReceivedDispatchedAction?.action)
        sut.dispatch("5", from: .here())
        XCTAssertEqual("5", mock.dispatchReceivedDispatchedAction?.action)

        XCTAssertEqual(5, mock.dispatchCallsCount)
    }

    func testActionHandlerClosureErased() {
        var actions: [String] = []
        let sut = AnyStoreType<String, Void>(
            action: { dispatchedAction in
                actions.append(dispatchedAction.action)
            },
            state: .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        )

        sut.dispatch("1", from: .here())
        sut.dispatch("2", from: .here())
        sut.dispatch("3", from: .here())
        sut.dispatch("4", from: .here())
        sut.dispatch("5", from: .here())

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramap() {
        var actions: [String] = []
        let stringHandler = AnyStoreType<String, Never>(
            action: { dispatchedAction in
                actions.append(dispatchedAction.action)
            },
            state: .init(subscribe: { _ in preconditionFailure("no state when it's never") })
        )
        let intHandler: AnyActionHandler<Int> = stringHandler.contramap { "\($0)" }

        intHandler.dispatch(1, from: .here())
        intHandler.dispatch(2, from: .here())
        intHandler.dispatch(3, from: .here())
        intHandler.dispatch(4, from: .here())
        intHandler.dispatch(5, from: .here())

        XCTAssertEqual(["1", "2", "3", "4", "5"], actions)
    }

    func testActionHandlerContramapAction() {
        var actions: [String] = []
        let publisher = PublisherType<Bool, Never> { subscriber in
            subscriber.onValue(true)
            return FooSubscription()
        }
        let stringHandler = AnyStoreType<String, Bool>(
            action: { dispatchedAction in
                actions.append(dispatchedAction.action)
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

        intHandler.dispatch(1, from: .here())
        intHandler.dispatch(2, from: .here())
        intHandler.dispatch(3, from: .here())
        intHandler.dispatch(4, from: .here())
        intHandler.dispatch(5, from: .here())

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
            action: { dispatchedAction in
                XCTAssertTrue(dispatchedAction.action)
                XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
                XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
                XCTAssertEqual(1, dispatchedAction.dispatcher.line)
                XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
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
        stringProvider.dispatch(true, from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"))

        wait(for: [shouldCallClosure, shouldCallAction], timeout: 0.1)
    }
}
