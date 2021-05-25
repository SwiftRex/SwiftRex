@testable import SwiftRex
import XCTest

class LiftAnyMiddlewareWrappingComposedTests: XCTestCase {
}

// MARK: - Lifting 3 properties at once
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareInputActionOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Input Action, Output Action
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareInputActionOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, TestState>()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                outputAction: { bar in AppAction.bar(bar) }
            )

        let uuid = UUID()
        generalMiddleware.receiveContext(getState: { TestState(value: uuid, name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Input Action, State
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareInputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar },
                state: { (global: TestState) in global.name }
            )

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting 2 properties at once: Output Action, State
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareOutputActionInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputActionInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputActionInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) },
                state: { (global: TestState) in global.name }
            )

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: Input Action
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareInputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(3, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction.Bar, AppAction, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware =
            composed.lift(
                inputAction: { (global: AppAction) in global.bar }
            )

        let uuid = UUID()
        generalMiddleware.receiveContext(getState: { TestState(value: uuid, name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: Output Action
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareOutputAction_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputAction_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareOutputAction_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction.Bar, TestState>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var middlewareGetState: (() -> TestState)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware =
            composed.lift(
                outputAction: { bar in AppAction.bar(bar) }
            )

        let uuid = UUID()
        generalMiddleware.receiveContext(getState: { TestState(value: uuid, name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual(TestState(value: uuid, name: "test-unlift-state"), middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}

// MARK: - Lifting a single property: State
extension LiftAnyMiddlewareWrappingComposedTests {
    func testLiftMiddlewareInputState_OutputActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { dispatchedAction in globalReceived.append(dispatchedAction.action) }

        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.bar(.echo), from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.bar(.delta), from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputState_RelevantInputActionsArriveFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        var receivedActions = [AppAction]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .foo, from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.bravo), from: .here(), state: { .init() })
        _ = generalMiddleware.handle(action: .bar(.delta), from: .here(), state: { .init() })

        XCTAssertEqual(4, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }

    func testLiftMiddlewareInputState_LocalInputStateIsExtractedFromGlobalContext() {
        let nameMiddleware = MiddlewareMock<AppAction, AppAction, String>()
        let composed = (nameMiddleware <> IdentityMiddleware()).eraseToAnyMiddleware()
        var middlewareGetState: (() -> String)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware =
            composed.lift(
                state: { (global: TestState) in global.name }
            )

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
        XCTAssertEqual(generalMiddleware.isComposed?.middlewares.count, 1)
    }
}
