import Foundation
@testable import SwiftRex
import XCTest

class StoreProjectionTests: XCTestCase {
    func testStoreProjectionDispatchesActionToUpstream() {
        let stateSubject = CurrentValueSubject(currentValue: TestState())
        let shouldCallUpstreamActionHandler = expectation(description: "upstream action handler should have been called")
        let upstreamActionHandler: (DispatchedAction<AppAction>) -> Void = { dispatchedAction in
            XCTAssertEqual(.bar(.delta), dispatchedAction.action)
            XCTAssertEqual("file_1", dispatchedAction.dispatcher.file)
            XCTAssertEqual("function_1", dispatchedAction.dispatcher.function)
            XCTAssertEqual(1, dispatchedAction.dispatcher.line)
            XCTAssertEqual("info_1", dispatchedAction.dispatcher.info)
            shouldCallUpstreamActionHandler.fulfill()
        }
        let sut = StoreProjection<AppAction, TestState>(action: upstreamActionHandler, state: stateSubject.subject.publisher)
        sut.dispatch(.bar(.delta), from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"))
        wait(for: [shouldCallUpstreamActionHandler], timeout: 0.1)
    }

    func testStoreProjectionForwardsStateFromUpstream() {
        let initialState = TestState()
        let shouldNotifyInitialState = expectation(description: "initial state should have been notified")
        let stateSubject = CurrentValueSubject(currentValue: initialState)
        let sut = StoreProjection<AppAction, TestState>(action: { _ in }, state: stateSubject.subject.publisher)
        _ = sut.statePublisher.subscribe(.init(onValue: { state in
            XCTAssertEqual(state, initialState)
            shouldNotifyInitialState.fulfill()
        }, onCompleted: nil))
        stateSubject.subject.subscriber.onValue(initialState)
        wait(for: [shouldNotifyInitialState], timeout: 0.1)
    }

    func testStoreProjectionDispatchesActionToUpstreamStore() {
        let stateSubject = CurrentValueSubject(currentValue: TestState())
        let shouldCallUpstreamActionHandler = expectation(description: "upstream action handler should have been called")
        let shouldCallReducer = expectation(description: "reducer should have been called")
        let reducerMock = createReducerMock()

        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        middlewareMock.handleActionFromAfterReducerClosure = { action, dispatcher, _ in
            XCTAssertEqual(.bar(.delta), action)
            XCTAssertEqual("file_1", dispatcher.file)
            XCTAssertEqual("function_1", dispatcher.function)
            XCTAssertEqual(1, dispatcher.line)
            XCTAssertEqual("info_1", dispatcher.info)
            shouldCallUpstreamActionHandler.fulfill()
        }

        reducerMock.1.reduceClosure = { action, state in
            XCTAssertEqual(.bar(.delta), action)
            shouldCallReducer.fulfill()
            return state
        }

        let originalStore = ReduxStoreBase<AppAction, TestState>(
            subject: stateSubject.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock
        )

        struct MockViewAction {
            let name: String
        }

        let sut = originalStore.projection(
            action: { (viewAction: MockViewAction) in
                guard viewAction.name == "delta" else { return nil }
                return AppAction.bar(.delta)
            },
            state: { $0 }
        )

        sut.dispatch(MockViewAction(name: "delta"), from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"))
        sut.dispatch(MockViewAction(name: "ignore"), from: .init(file: "file_2", function: "function_2", line: 2, info: "info_2"))

        wait(for: [shouldCallUpstreamActionHandler, shouldCallReducer], timeout: 0.1, enforceOrder: true)
    }

    func testStoreProjectionForwardsStateFromUpstreamStore() {
        let initialState = TestState(value: .init(), name: "this comes from original store")
        let shouldNotifyInitialState = expectation(description: "initial state should have been notified")
        let stateSubject = CurrentValueSubject(currentValue: initialState)

        let originalStore = ReduxStoreBase<AppAction, TestState>(
            subject: stateSubject.subject,
            reducer: createReducerMock().0,
            middleware: IsoMiddlewareMock<AppAction, TestState>()
        )

        struct MockViewState: Equatable {
            let decoratedValue: String
            let decoratedName: String
        }

        let sut = originalStore.projection(
            action: { $0 },
            state: { (state: TestState) -> MockViewState in
                MockViewState(
                    decoratedValue: "*** " + state.value.uuidString + " ***",
                    decoratedName: "*** " + state.name + " ***"
                )
            }
        )

        _ = sut.statePublisher.subscribe(.init(onValue: { state in
            XCTAssertEqual(state, .init(
                decoratedValue: "*** " + initialState.value.uuidString + " ***",
                decoratedName: "*** this comes from original store ***"
            ))
            shouldNotifyInitialState.fulfill()
        }, onCompleted: nil))

        stateSubject.subject.subscriber.onValue(initialState)
        wait(for: [shouldNotifyInitialState], timeout: 0.1)
    }
}
