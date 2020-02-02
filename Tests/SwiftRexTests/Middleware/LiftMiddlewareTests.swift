@testable import SwiftRex
import XCTest

class LiftMiddlewareTests: XCTestCase {
    func testLiftMiddlewareNewActionsAreForwardedToGlobalContext() {
        var localDispatcher: AnyActionHandler<AppAction.Bar>?
        var globalReceived: [AppAction] = []
        let globalDispatcher: AnyActionHandler<AppAction> = .init { globalReceived.append($0) }

        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
            inputActionMap: { $0.bar },
            outputActionMap: { bar in .bar(bar) },
            stateMap: { $0.name }
        )
        nameMiddleware.receiveContextGetStateOutputClosure = { _, output in localDispatcher = output }
        generalMiddleware.receiveContext(getState: { TestState() }, output: globalDispatcher)

        localDispatcher?.dispatch(.echo)
        globalDispatcher.dispatch(.foo)
        globalDispatcher.dispatch(.bar(.bravo))
        localDispatcher?.dispatch(.delta)

        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(globalReceived, expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareForwardsActionsFromTheGlobalMiddleware() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionClosure = { action in
            receivedActions.append(action)
            return .doNothing()
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
                inputActionMap: { $0.bar },
                outputActionMap: { bar in .bar(bar) },
                stateMap: { $0.name }
            )

        _ = generalMiddleware.handle(action: .bar(.echo))
        _ = generalMiddleware.handle(action: .foo)
        _ = generalMiddleware.handle(action: .bar(.bravo))
        _ = generalMiddleware.handle(action: .bar(.delta))

        XCTAssertEqual(3, nameMiddleware.handleActionCallsCount)
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

        generalMiddleware.receiveContext(getState: { TestState(value: .init(), name: "test-unlift-state") }, output: .init { _ in })

        XCTAssertEqual("test-unlift-state", middlewareGetState?())
    }
}
