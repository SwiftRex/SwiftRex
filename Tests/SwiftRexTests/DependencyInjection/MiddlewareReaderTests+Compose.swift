@testable import SwiftRex
import XCTest

// MARK: - Compose non-monoid
extension MiddlewareReaderTests {
    func testMiddlewareReaderComposedMiddlewareAction() {
        var newActions = [AppAction]()
        let originalActions: [AppAction] = [.foo, .bar(.alpha), .bar(.alpha), .bar(.bravo), .bar(.echo), .foo]
        var originalActionsReceived: [(middlewareName: String, action: AppAction)] = []
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain should have been called")
        let expectedNewActions: [AppAction] = [
            .foo, .foo, .bar(.alpha), .bar(.alpha), .bar(.alpha), .bar(.alpha),
            .bar(.bravo), .bar(.bravo), .bar(.echo), .bar(.echo), .foo, .foo
        ]

        lastInChainWasCalledExpectation.expectedFulfillmentCount = expectedNewActions.count

        let readers = ["m1", "m2"]
            .lazy
            .map { name in
                MiddlewareReader<String, IsoMiddlewareMock<AppAction, TestState>> { dependency -> IsoMiddlewareMock<AppAction, TestState> in
                    XCTAssertEqual("injected dependency", dependency)
                    let middleware = IsoMiddlewareMock<AppAction, TestState>()
                    middleware.handleActionFromStateClosure = { action, dispatcher, _ in
                        originalActionsReceived.append((middlewareName: name, action: action))
                        XCTAssertEqual("file_1", dispatcher.file)
                        XCTAssertEqual("function_1", dispatcher.function)
                        XCTAssertEqual(1, dispatcher.line)
                        XCTAssertEqual("info_1", dispatcher.info)
                        return IO { output in
                            output.dispatch(action, from: .init(file: "file_2", function: "function_2", line: 2, info: "info_2"))
                            lastInChainWasCalledExpectation.fulfill()
                        }
                    }
                    return middleware
                }
            }

        let sut = (readers[0] <> readers[1]).inject("injected dependency")

        originalActions.forEach { originalAction in
            let io = sut.handle(action: originalAction,
                                from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"),
                                state: { TestState() })
            io.runIO(.init({ dispatchedAction in newActions.append(dispatchedAction.action) }))
        }

        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(newActions, expectedNewActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m1" }.map { $0.action }, originalActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m2" }.map { $0.action }, originalActions)
    }

    func testMiddlewareReaderActionHandlerPropagationFromComposedMiddlewareToChildrenComposedViaOperator() {
        let shouldReceiveContext = expectation(description: "context should have been received")
        shouldReceiveContext.expectedFulfillmentCount = 4
        let readers = ["m1", "m2", "m3", "m4"]
            .map { _ in
                MiddlewareReader { (dependency: String) -> IsoMiddlewareMock<AppAction, TestState> in
                    XCTAssertEqual("injected dependency", dependency)
                    let middleware = IsoMiddlewareMock<AppAction, TestState>()
                    middleware.receiveContextGetStateOutputClosure = { _, _ in
                        shouldReceiveContext.fulfill()
                    }
                    middleware.handleActionFromStateClosure = { _, _, _ in .pure() }
                    return middleware
                }
            }

        let composedReaders = readers[0] <> readers[1] <> readers[2] <> readers[3]
        let composedMiddlewares = composedReaders.inject("injected dependency")
        composedMiddlewares.receiveContext(getState: { TestState() }, output: .init({ _ in }))

        wait(for: [shouldReceiveContext], timeout: 0.1)
    }

    func testMiddlewareReaderMiddlewareActionHandlerPropagationFromComposedMiddlewareToChildrenComposedViaAppend() {
        let shouldReceiveContext = expectation(description: "context should have been received")
        shouldReceiveContext.expectedFulfillmentCount = 4
        let composedMiddlewares = ["m1", "m2", "m3", "m4"]
            .map { _ in
                MiddlewareReader { (dependency: String) -> IsoMiddlewareMock<AppAction, TestState> in
                    XCTAssertEqual("injected dependency", dependency)
                    let middleware = IsoMiddlewareMock<AppAction, TestState>()
                    middleware.receiveContextGetStateOutputClosure = { _, _ in
                        shouldReceiveContext.fulfill()
                    }
                    middleware.handleActionFromStateClosure = { _, _, _ in .pure() }
                    return middleware
                }
            }
            .reduce(MiddlewareReader<String, ComposedMiddleware<AppAction, AppAction, TestState>>.identity, <>)
            .inject("injected dependency")

        composedMiddlewares.receiveContext(getState: { TestState() }, output: .init({ _ in }))
        wait(for: [shouldReceiveContext], timeout: 0.1)
    }
}

// MARK: - Compose monoid
extension MiddlewareReaderTests {
    func testMiddlewareReaderComposedMonoidMiddlewareAction() {
        var newActions = [AppAction]()
        let originalActions: [AppAction] = [.foo, .bar(.alpha), .bar(.alpha), .bar(.bravo), .bar(.echo), .foo]
        var originalActionsReceived: [(middlewareName: String, action: AppAction)] = []
        let lastInChainWasCalledExpectation = self.expectation(description: "last in chain should have been called")
        let expectedNewActions: [AppAction] = [
            .foo, .foo, .bar(.alpha), .bar(.alpha), .bar(.alpha), .bar(.alpha),
            .bar(.bravo), .bar(.bravo), .bar(.echo), .bar(.echo), .foo, .foo
        ]

        lastInChainWasCalledExpectation.expectedFulfillmentCount = expectedNewActions.count

        let readers = ["m1", "m2"]
            .lazy
            .map { name in
                MiddlewareReader<String, MonoidMiddleware<AppAction, AppAction, TestState>> { dependency
                -> MonoidMiddleware<AppAction, AppAction, TestState> in
                    XCTAssertEqual("injected dependency", dependency)
                    let middleware = MonoidMiddleware<AppAction, AppAction, TestState>(string: name)
                    middleware.mock.handleActionFromStateClosure = { action, dispatcher, _ in
                        originalActionsReceived.append((middlewareName: name, action: action))
                        XCTAssertEqual("file_1", dispatcher.file)
                        XCTAssertEqual("function_1", dispatcher.function)
                        XCTAssertEqual(1, dispatcher.line)
                        XCTAssertEqual("info_1", dispatcher.info)
                        return IO { output in
                            output.dispatch(action, from: .init(file: "file_2", function: "function_2", line: 2, info: "info_2"))
                            lastInChainWasCalledExpectation.fulfill()
                        }
                    }
                    return middleware
                }
            }

        let sut = (readers[0] <> readers[1]).inject("injected dependency")

        originalActions.forEach { originalAction in
            sut.handle(action: originalAction,
                       from: .init(file: "file_1", function: "function_1", line: 1, info: "info_1"),
                       state: { TestState() })
                .runIO(.init({ dispatchedAction in newActions.append(dispatchedAction.action) }))
        }

        XCTAssertEqual("m1m2", sut.string)

        wait(for: [lastInChainWasCalledExpectation], timeout: 3)

        XCTAssertEqual(newActions, expectedNewActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m1" }.map { $0.action }, originalActions)
        XCTAssertEqual(originalActionsReceived.filter { $0.middlewareName == "m2" }.map { $0.action }, originalActions)
    }
}
