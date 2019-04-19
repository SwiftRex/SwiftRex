#if canImport(ReactiveSwift)
import Foundation
import ReactiveSwift
@testable import SwiftRex
import XCTest

class StoreBaseTests: XCTestCase {
    func testStoreDispatchEvent() {
        // Given
        let event = Event1()
        let (reducer, reducerMock) = createReducerMock()
        let middleware1 = MiddlewareMock<TestState>()
        let middleware2 = MiddlewareMock<TestState>()
        let middleware2ShouldRun = expectation(description: "Middleware 2 should run")

        middleware1.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducerMock.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
        }
        middleware2.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducerMock.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
            middleware2ShouldRun.fulfill()
        }

        let sut = TestStore(initialState: TestState(),
                            reducer: reducer,
                            middleware: middleware1 <> middleware2)

        // Then
        sut.dispatch(event)
        wait(for: [middleware2ShouldRun], timeout: 2)

        // Expect
        XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, reducerMock.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
    }

    func testStoreTriggerAction() {
        // Given
        let action = Action1()
        let middleware1 = MiddlewareMock<TestState>()
        let middleware2 = MiddlewareMock<TestState>()
        let reducerShouldRun = expectation(description: "Reducer should run")
        let (reducer, reducerMock) = createReducerMock()
        middleware1.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducerMock.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        middleware2.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducerMock.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        reducerMock.reduceActionClosure = { reduceState, reduceAction in
            XCTAssertEqual(action, reduceAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, reducerMock.reduceActionCallsCount)
            XCTAssertEqual("", reduceState.name)
            reducerShouldRun.fulfill()
            return TestState(value: UUID(), name: "reduced")
        }
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer,
                            middleware: middleware1 <> middleware2)

        // Then
        sut.trigger(action)
        wait(for: [reducerShouldRun], timeout: 2)

        // Expect
        XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, reducerMock.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
    }

    func testStoreSubscriptionSubscribeOnly() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextOnce = expectation(description: "onNext called once")
        callOnNextOnce.expectedFulfillmentCount = 1
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)

        // Then
        _ = sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextOnce.fulfill()
            }
        ).start()

        wait(for: [callOnNextOnce], timeout: 2)

        // Expect
        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")
    }

    func testStoreSubscriptionTriggerOnce() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextTwice = expectation(description: "onNext called twice")
        callOnNextTwice.expectedFulfillmentCount = 2
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)

        // Then
        _ = sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextTwice.fulfill()
            }
        ).start()

        sut.trigger(Action1())

        wait(for: [callOnNextTwice], timeout: 2)

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual("action1", state!.name)
    }

    func testStoreSubscriptionTriggerTwice() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextThrice = expectation(description: "onNext called thrice")
        callOnNextThrice.expectedFulfillmentCount = 3
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        _ = sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextThrice.fulfill()
            }
        ).start()

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action2())

        wait(for: [callOnNextThrice], timeout: 2)

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action2")
    }

    func testStoreSubscriptionTriggerTwiceSameAction() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextThrice = expectation(description: "onNext called thrice")
        callOnNextThrice.expectedFulfillmentCount = 3
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        _ = sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextThrice.fulfill()
            }
        ).start()

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action1())

        wait(for: [callOnNextThrice], timeout: 2)

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceSameActionDistinct() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextTwice = expectation(description: "onNext called twice")
        callOnNextTwice.expectedFulfillmentCount = 2
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        _ = sut.producer.skipRepeats().on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextTwice.fulfill()
            }
        ).start()

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action1())

        wait(for: [callOnNextTwice], timeout: 2)

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceWithOneUnknownAction() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextThrice = expectation(description: "onNext called thrice")
        callOnNextThrice.expectedFulfillmentCount = 3
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        _ = sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextThrice.fulfill()
            }
        ).start()

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action3())

        wait(for: [callOnNextThrice], timeout: 2)

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceWithOneUnknownActionDistinct() {
        // Given
        let reducer = createNameReducer()
        var state: TestState?
        var changes = 0
        let callOnNextTwice = expectation(description: "onNext called twice")
        callOnNextTwice.expectedFulfillmentCount = 2
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        _ = sut.producer.skipRepeats().on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            value: { newState in
                state = newState
                changes += 1
                callOnNextTwice.fulfill()
            }
        ).start()

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action3())

        wait(for: [callOnNextTwice], timeout: 2)

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionDispose() {
        // Given
        let reducer = createNameReducer()
        var changes = 0
        let callOnNextTwice = expectation(description: "onNext called twice")
        callOnNextTwice.expectedFulfillmentCount = 2
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        let shouldDispose = expectation(description: "it should dispose the subscription")

        // Then
        var dispose: ScopedDisposable? = ScopedDisposable(sut.producer.on(
            failed: { error in
                XCTFail(error.localizedDescription)
            },
            completed: {
                XCTFail("should never complete")
            },
            interrupted: {
                shouldDispose.fulfill()
            },
            value: { _ in
                changes += 1
                callOnNextTwice.fulfill()
            }
        ).start())

        sut.trigger(Action1())

        wait(for: [callOnNextTwice], timeout: 2)
        XCTAssert(dispose?.isDisposed == false)

        // Expect
        XCTAssertEqual(2, changes)
        dispose = nil
        wait(for: [shouldDispose], timeout: 0)
    }

    func testStoreSubscriptionReuseAfterDispose() { // swiftlint:disable:this function_body_length
        // Given
        let reducer = createNameReducer()

        let callOnNextFirstObserver = expectation(description: "first observer onNext should be called")
        let callOnNextSecondObserverTwice = expectation(description: "second observer onNext should be called twice")
        callOnNextSecondObserverTwice.expectedFulfillmentCount = 2
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        let shouldDispose1 = expectation(description: "it should dispose the subscription")
        let shouldDispose2 = expectation(description: "it should dispose the subscription")
        let action2DispatchedWithoutSubscribers = expectation(for: NSPredicate(block: { any, _ in
            (any as? TestStore)?.value.name == "action2"
        }), evaluatedWith: sut)

        // Then
        var dispose1: ScopedDisposable? = ScopedDisposable(sut.producer.on(
            failed: { error in XCTFail(error.localizedDescription) },
            completed: { XCTFail("should never complete") },
            interrupted: { shouldDispose1.fulfill() },
            value: { value in
                XCTAssertEqual("", value.name)
                callOnNextFirstObserver.fulfill()
            }
        ).start())

        wait(for: [callOnNextFirstObserver], timeout: 1)
        XCTAssert(dispose1?.isDisposed == false)
        dispose1 = nil
        wait(for: [shouldDispose1], timeout: 0)

        sut.trigger(Action1())
        sut.trigger(Action2())
        print("start wait \(Date())")
        wait(for: [action2DispatchedWithoutSubscribers], timeout: 10)
        print(sut.value.name)
        print("end wait \(Date())")

        var action = 2
        var dispose2: ScopedDisposable? = ScopedDisposable(sut.producer.on(
            failed: { error in XCTFail(error.localizedDescription) },
            completed: { XCTFail("should never complete") },
            interrupted: { shouldDispose2.fulfill() },
            value: { value in
                switch action {
                case 2: XCTAssertEqual(value.name, "action2")
                case 3: XCTAssertEqual(value.name, "action1")
                default: XCTFail("Action shuold be 2 or 3, never \(value)")
                }
                action += 1
                callOnNextSecondObserverTwice.fulfill()
            }
        ).start())

        sut.trigger(Action1())
        wait(for: [callOnNextSecondObserverTwice], timeout: 2)
        XCTAssert(dispose2?.isDisposed == false)
        dispose2 = nil
        wait(for: [shouldDispose2], timeout: 0)

        // Expect
        XCTAssertEqual(sut.value.name, "action1")
    }
}
#endif
