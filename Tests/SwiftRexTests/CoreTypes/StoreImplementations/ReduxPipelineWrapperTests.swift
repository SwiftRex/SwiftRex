import Foundation
@testable import SwiftRex
import XCTest

class ReduxPipelineWrapperTests: XCTestCase {
    func testDispatchCallOnActionAlwaysInMainThread() {
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let stateSubjectMock = CurrentValueSubject(currentValue: TestState())
        let sut = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: createReducerMock().0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallMiddlewareActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionNextClosure = { action, _ in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            shouldCallMiddlewareActionHandler.fulfill()
        }

        DispatchQueue.global().async {
            sut.dispatch(actionToDispatch)
        }

        wait(for: [shouldCallMiddlewareActionHandler], timeout: 0.1)
    }

    func testMiddlewareDispatchesNewActionsBackToTheStore() {
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let stateSubjectMock = CurrentValueSubject(currentValue: TestState())
        _ = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: createReducerMock().0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallMiddlewareActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionNextClosure = { action, _ in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            shouldCallMiddlewareActionHandler.fulfill()
        }

        DispatchQueue.global().async {
            middlewareMock.context().dispatch(actionToDispatch)
        }

        wait(for: [shouldCallMiddlewareActionHandler], timeout: 0.1)
    }

    func testMiddlewareGetStateIsSetCorrectly() {
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let currentState = TestState()
        let stateSubjectMock = CurrentValueSubject(currentValue: currentState)
        _ = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: createReducerMock().0,
            middleware: middlewareMock)
        XCTAssertEqual(currentState, middlewareMock.context().getState())
    }

    func testReducersPipelineWillBeWiredToTheEndOfMiddlewarePipeline() {
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let initialState = TestState()
        let stateSubjectMock = CurrentValueSubject(currentValue: initialState)
        let reducerMock = createReducerMock()
        let sut = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallReducerActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionNextClosure = { _, next in
            next()
        }

        reducerMock.1.reduceClosure = { action, state in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            XCTAssertEqual(initialState, state)
            shouldCallReducerActionHandler.fulfill()
            return state
        }

        DispatchQueue.global().async {
            sut.dispatch(actionToDispatch)
        }

        wait(for: [shouldCallReducerActionHandler], timeout: 0.1)
    }

    func testReducersChangeTheState() {
        let middlewareMock = MiddlewareMock<AppAction, TestState>()
        let initialState = TestState()
        let reducedState = TestState(value: UUID(), name: "reduced state")
        let stateSubjectMock = CurrentValueSubject(currentValue: initialState)
        let reducerMock = createReducerMock()
        let sut = ReduxPipelineWrapper<MiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let shouldCallReducerActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionNextClosure = { _, next in
            next()
        }

        reducerMock.1.reduceClosure = { _, state in
            XCTAssertEqual(initialState, state)
            shouldCallReducerActionHandler.fulfill()
            return reducedState
        }

        sut.dispatch(.bar(.charlie))

        wait(for: [shouldCallReducerActionHandler], timeout: 0.1)
        XCTAssertEqual(reducedState, stateSubjectMock.currentValue)
        XCTAssertNotEqual(initialState, stateSubjectMock.currentValue)
    }
}
