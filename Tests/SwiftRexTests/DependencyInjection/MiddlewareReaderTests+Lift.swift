@testable import SwiftRex
import XCTest

// swiftlint:disable file_length
extension MiddlewareReaderTests {
    private var globalInputActions: [Int] { fiboInts }
    private var globalOutputActions: [String] { primesString }
    private var globalState: Int { hitchhikerInt }
    private var globalDependencies: Int { sheldonsFavoriteInt }
    private var localInputActions: [String] { fiboStrings }
    private var localOutputActions: [Int] { primesInt }
    private var localState: String { hitchhikerString }
    private var localDependencies: String { sheldonsFavoriteString }
    private typealias LocalTestReader = MiddlewareReader<String, MiddlewareMock<String, Int, String>>
    private func stringify(_ int: Int) -> String { String(int) }
    private func stringify2(_ int: Int) -> String? { String(int) }

    // MARK: - all 4
    func testMiddlewareReaderLift_InputAction_OutputAction_State_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            outputAction: stringify,
            state: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        globalInputActions.forEach { _ =
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    // MARK: - 3
    func testMiddlewareReaderLift_OutputAction_State_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            outputAction: stringify,
            state: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        localInputActions.forEach { _ =
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_InputAction_State_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            state: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_InputAction_OutputAction_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            outputAction: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_InputAction_OutputAction_State() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            outputAction: stringify,
            state: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    // MARK: - 2
    func testMiddlewareReaderLift_InputAction_OutputAction() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            outputAction: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_InputAction_State() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            state: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_InputAction_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_OutputAction_State() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            outputAction: stringify,
            state: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)

        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_OutputAction_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            outputAction: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_State_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            state: stringify,
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    // MARK: - only 1
    func testMiddlewareReaderLift_InputAction() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            inputAction: stringify2
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        globalInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_OutputAction() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [String] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<String> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            outputAction: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch("foo", from: .here())

        // Then
        XCTAssertEqual(globalReceived, globalOutputActions + ["foo"])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_State() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            state: stringify
        )
        let globalMiddleware = globalReader.inject(localDependencies)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { self.globalState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }

    func testMiddlewareReaderLift_Dependencies() {
        // Given
        let localState = self.localState
        let localOutputActions = self.localOutputActions
        var globalReceived: [Int] = []
        var receivedLocalInputActions = [String]()
        let globalDispatcher: AnyActionHandler<Int> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let localReader = LocalTestReader { dependencies in
            XCTAssertEqual(self.localDependencies, dependencies)
            let localMiddleware = MiddlewareMock<String, Int, String>()
            localMiddleware.handleActionFromStateClosure = { action, _, state in
                receivedLocalInputActions.append(action)
                XCTAssertEqual(localState, state())
                // Start emitting all the primes, once it got all the fibbo
                guard action == "55" else { return .pure() }

                return IO { output in
                    localOutputActions.forEach { output.dispatch($0, from: .here()) }
                }
            }
            return localMiddleware
        }

        // Setup
        let globalReader = localReader.lift(
            dependencies: stringify
        )
        let globalMiddleware = globalReader.inject(globalDependencies)
        globalMiddleware.receiveContext(getState: { self.localState }, output: globalDispatcher)

        // When
        localInputActions.forEach {
            globalMiddleware
                .handle(action: $0, from: .here(), state: { localState })
                .runIO(globalDispatcher)
        }
        globalDispatcher.dispatch(9, from: .here())

        // Then
        XCTAssertEqual(globalReceived, localOutputActions + [9])
        XCTAssertEqual(receivedLocalInputActions, localInputActions)
    }
}

private let fiboInts = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]
private let fiboStrings = ["1", "1", "2", "3", "5", "8", "13", "21", "34", "55"]
private let primesInt = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
private let primesString = ["2", "3", "5", "7", "11", "13", "17", "19", "23", "29"]
private let hitchhikerInt = 42
private let hitchhikerString = "42"
private let sheldonsFavoriteInt = 73
private let sheldonsFavoriteString = "73"
