import Foundation
@testable import SwiftRex
import XCTest

class ReduxPipelineWrapperTests: XCTestCase {
    func testDispatchCallOnActionAlwaysInMainThread() {
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        let stateSubjectMock = CurrentValueSubject(currentValue: TestState())
        let reducerMock = createReducerMock()
        reducerMock.1.reduceClosure = { _, state in state }
        let sut = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallMiddlewareActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionFromAfterReducerClosure = { action, dispatcher, _ in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            XCTAssertEqual("file_1", dispatcher.file)
            XCTAssertEqual("function_1", dispatcher.function)
            XCTAssertEqual(1, dispatcher.line)
            XCTAssertEqual("info_1", dispatcher.info)
            shouldCallMiddlewareActionHandler.fulfill()
        }

        DispatchQueue.global().async {
            sut.dispatch(actionToDispatch, from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"))
        }

        wait(for: [shouldCallMiddlewareActionHandler], timeout: 0.1)
    }

    func testMiddlewareDispatchesNewActionsBackToTheStore() {
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        var middlewareDispatcher: AnyActionHandler<AppAction>?
        middlewareMock.receiveContextGetStateOutputClosure = { _, output in
            middlewareDispatcher = output
        }
        let stateSubjectMock = CurrentValueSubject(currentValue: TestState())
        let reducerMock = createReducerMock()
        reducerMock.1.reduceClosure = { _, state in state }

        // we have to hold the wrapper here
        // otherwise middleware will be freed immediately and fail the test
        let wrapperHolder = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallMiddlewareActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionFromAfterReducerClosure = { action, dispatcher, _ in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            XCTAssertEqual("file_1", dispatcher.file)
            XCTAssertEqual("function_1", dispatcher.function)
            XCTAssertEqual(1, dispatcher.line)
            XCTAssertEqual("info_1", dispatcher.info)
            shouldCallMiddlewareActionHandler.fulfill()
        }

        DispatchQueue.global().async {
            middlewareDispatcher?.dispatch(actionToDispatch, from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"))
        }

        wait(for: [shouldCallMiddlewareActionHandler], timeout: 0.1)
        _ = wrapperHolder
    }

    func testMiddlewareGetStateIsSetCorrectly() {
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        var middlewareGetState: (() -> TestState)?
        middlewareMock.receiveContextGetStateOutputClosure = { getState, _ in
            middlewareGetState = getState
        }
        let currentState = TestState()
        let stateSubjectMock = CurrentValueSubject(currentValue: currentState)
        _ = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: createReducerMock().0,
            middleware: middlewareMock)
        XCTAssertEqual(currentState, middlewareGetState?())
    }

    func testReducersPipelineWillBeWiredToTheEndOfMiddlewarePipeline() {
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        let initialState = TestState()
        let stateSubjectMock = CurrentValueSubject(currentValue: initialState)
        let reducerMock = createReducerMock()
        let sut = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let actionToDispatch: AppAction = .bar(.charlie)
        let expectedAction: AppAction = .bar(.charlie)
        let shouldCallReducerActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionFromAfterReducerClosure = { _, _, _ in
        }

        reducerMock.1.reduceClosure = { action, state in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(action, expectedAction)
            XCTAssertEqual(initialState, state)
            shouldCallReducerActionHandler.fulfill()
            return state
        }

        DispatchQueue.global().async {
            sut.dispatch(actionToDispatch, from: .here())
        }

        wait(for: [shouldCallReducerActionHandler], timeout: 0.1)
    }

    func testReducersChangeTheState() {
        let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
        let initialState = TestState()
        let reducedState = TestState(value: UUID(), name: "reduced state")
        let stateSubjectMock = CurrentValueSubject(currentValue: initialState)
        let reducerMock = createReducerMock()
        let sut = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
            state: stateSubjectMock.subject,
            reducer: reducerMock.0,
            middleware: middlewareMock)

        let shouldCallReducerActionHandler = expectation(description: "middleware action handler should have been called")
        middlewareMock.handleActionFromAfterReducerClosure = { _, _, _ in
        }

        reducerMock.1.reduceClosure = { _, state in
            XCTAssertEqual(initialState, state)
            shouldCallReducerActionHandler.fulfill()
            return reducedState
        }

        sut.dispatch(.bar(.charlie), from: .here())

        wait(for: [shouldCallReducerActionHandler], timeout: 0.1)
        XCTAssertEqual(reducedState, stateSubjectMock.currentValue)
        XCTAssertNotEqual(initialState, stateSubjectMock.currentValue)
    }

    func testMiddlewareShouldNotLeak() {
        weak var middlewareRef: IsoMiddlewareMock<AppAction, TestState>?

        autoreleasepool {
            let middlewareMock = IsoMiddlewareMock<AppAction, TestState>()
            middlewareRef = middlewareMock

            let stateSubjectMock = CurrentValueSubject(currentValue: TestState())
            let reducerMock = createReducerMock()
            _ = ReduxPipelineWrapper<IsoMiddlewareMock<AppAction, TestState>>(
                state: stateSubjectMock.subject,
                reducer: reducerMock.0,
                middleware: middlewareMock
            )
        }

        XCTAssertTrue(middlewareRef == nil, "middleware should be freed")
    }
}
