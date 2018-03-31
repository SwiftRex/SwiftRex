import RxSwift
@testable import SwiftRex
import XCTest

class StoreBaseTests: XCTestCase {

    func testStoreDispatchEvent() {
        // Given
        let event = Event1()
        let reducer = ReducerMock()
        let middleware1 = MiddlewareMock()
        let middleware2 = MiddlewareMock()
        middleware1.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
        }
        middleware2.handleEventGetStateNextClosure = { chainEvent, getState, next in
            XCTAssertEqual(event, chainEvent as! Event1)
            XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainEvent, getState)
        }

        let sut = TestStore(initialState: TestState(),
                            reducer: reducer,
                            middleware: middleware1 >>> middleware2)

        // Then
        sut.dispatch(event)

        // Expect
        XCTAssertEqual(1, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, reducer.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
    }

    func testStoreTriggerAction() {
        // Given
        let action = Action1()
        let middleware1 = MiddlewareMock()
        let middleware2 = MiddlewareMock()
        let reducer = ReducerMock()
        middleware1.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        middleware2.handleActionGetStateNextClosure = { chainAction, getState, next in
            XCTAssertEqual(action, chainAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(0, reducer.reduceActionCallsCount)
            XCTAssertEqual("", getState().name)
            next(chainAction, getState)
        }
        reducer.reduceActionClosure = { reduceState, reduceAction in
            XCTAssertEqual(action, reduceAction as! Action1)
            XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
            XCTAssertEqual(1, reducer.reduceActionCallsCount)
            XCTAssertEqual("", reduceState.name)

            return TestState(value: UUID(), name: "reduced")
        }
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer,
                            middleware: middleware1 >>> middleware2)

        // Then
        sut.trigger(action)

        // Expect
        XCTAssertEqual(1, middleware1.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, middleware2.handleActionGetStateNextCallsCount)
        XCTAssertEqual(1, reducer.reduceActionCallsCount)
        XCTAssertEqual(0, middleware1.handleEventGetStateNextCallsCount)
        XCTAssertEqual(0, middleware2.handleEventGetStateNextCallsCount)
    }

    func testStoreSubscriptionSubscribeOnly() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)

        // Then
        sut.subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        // Expect
        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")
    }

    func testStoreSubscriptionTriggerOnce() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)

        // Then
        sut.subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        sut.trigger(Action1())

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwice() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        sut.subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action2())

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action2")
    }

    func testStoreSubscriptionTriggerTwiceSameAction() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        sut.subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action1())

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceSameActionDistinct() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        sut.distinctUntilChanged().subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action1())

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceWithOneUnknownAction() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        sut.subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action3())

        // Expect
        XCTAssertEqual(3, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionTriggerTwiceWithOneUnknownActionDistinct() {
        // Given
        let disposeBag = DisposeBag()
        let reducer = NameReducer()
        var state: TestState?
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        sut.distinctUntilChanged().subscribe(onNext: { newState in
            state = newState
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }).disposed(by: disposeBag)

        XCTAssertEqual(1, changes)
        XCTAssertEqual(state!.name, "")

        // Then
        sut.trigger(Action1())
        sut.trigger(Action3())

        // Expect
        XCTAssertEqual(2, changes)
        XCTAssertEqual(state!.name, "action1")
    }

    func testStoreSubscriptionDispose() {
        // Given
        var disposeBag: DisposeBag? = DisposeBag()
        let reducer = NameReducer()
        var changes = 0
        let sut = TestStore(initialState: TestState(),
                            reducer: reducer)
        let shouldDispose = expectation(description: "it should dispose the subscription")

        // Then
        sut.subscribe(onNext: { _ in
            changes += 1
        }, onError: { error in
            XCTFail(error.localizedDescription)
        }, onCompleted: {
            XCTFail("shoud never complete")
        }, onDisposed: {
            shouldDispose.fulfill()
        }).disposed(by: disposeBag!)

        sut.trigger(Action1())

        // Expect
        XCTAssertEqual(2, changes)
        disposeBag = nil
        wait(for: [shouldDispose], timeout: 0)
    }
}
