@testable import SwiftRex
import XCTest

class LiftMiddlewareTests: XCTestCase {
    func testLiftMiddlewareNewActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { action, _ in globalReceived.append(action) }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
            inputActionMap: { $0.bar },
            outputActionMap: { bar in .bar(bar) },
            stateMap: { $0.name }
        )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo, from: .here())
        globalDispatcher.dispatch(.foo, from: .here())
        globalDispatcher.dispatch(.bar(.bravo), from: .here())
        localDispatcher?.dispatch(.delta, from: .here())

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareForwardsActionsFromTheGlobalMiddleware() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionFromAfterReducerClosure = { action, _, _ in
            receivedActions.append(action)
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
                inputActionMap: { $0.bar },
                outputActionMap: { bar in .bar(bar) },
                stateMap: { $0.name }
            )

        var afterReducer: AfterReducer = .identity
        generalMiddleware.handle(action: .bar(.echo), from: .here(), afterReducer: &afterReducer)
        generalMiddleware.handle(action: .foo, from: .here(), afterReducer: &afterReducer)
        generalMiddleware.handle(action: .bar(.bravo), from: .here(), afterReducer: &afterReducer)
        generalMiddleware.handle(action: .bar(.delta), from: .here(), afterReducer: &afterReducer)

        XCTAssertEqual(3, nameMiddleware.handleActionFromAfterReducerCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareUnliftsStateForLocalMiddleware() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var middlewareGetState: (() -> String)?
        nameMiddleware.receiveContextGetStateOutputClosure = { getState, _ in middlewareGetState = getState }

        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
                inputActionMap: { $0.bar },
                outputActionMap: { bar in .bar(bar) },
                stateMap: { $0.name }
            )

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _, _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}
