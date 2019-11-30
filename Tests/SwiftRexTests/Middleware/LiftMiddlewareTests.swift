@testable import SwiftRex
import XCTest

typealias IsoMiddlewareMock<Action, State> = MiddlewareMock<Action, Action, State>

class LiftMiddlewareTests: XCTestCase {
    func testLiftMiddlewareNewActionsAreForwardedToGlobalContext() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let context = MiddlewareContextMock<AppAction, TestState>()
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
            actionZoomIn: { $0.bar },
            actionZoomOut: { bar in .bar(bar) },
            stateZoomIn: { $0.name }
        )
        generalMiddleware.context = { context.value }

        nameMiddleware.context().dispatch(.echo)
        generalMiddleware.context().dispatch(.foo)
        generalMiddleware.context().dispatch(.bar(.bravo))
        nameMiddleware.context().dispatch(.delta)

        XCTAssertEqual(4, context.onActionCount)
        let expectedActionsOnGlobalContext: [AppAction] = [.bar(.echo), .foo, .bar(.bravo), .bar(.delta)]
        XCTAssertEqual(context.onActionParameters, expectedActionsOnGlobalContext)
    }

    func testLiftMiddlewareForwardsActionsFromTheGlobalMiddleware() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        var receivedActions = [AppAction.Bar]()
        nameMiddleware.handleActionNextClosure = { action, _ in
            receivedActions.append(action)
        }
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
            actionZoomIn: { $0.bar },
            actionZoomOut: { bar in .bar(bar) },
            stateZoomIn: { $0.name }
        )

        generalMiddleware.handle(action: .bar(.echo), next: { })
        generalMiddleware.handle(action: .foo, next: { })
        generalMiddleware.handle(action: .bar(.bravo), next: { })
        generalMiddleware.handle(action: .bar(.delta), next: { })

        XCTAssertEqual(3, nameMiddleware.handleActionNextCallsCount)
        let expectedActionsOnLocalMiddleware: [AppAction.Bar] = [.echo, .bravo, .delta]
        XCTAssertEqual(receivedActions, expectedActionsOnLocalMiddleware)
    }

    func testLiftMiddlewareUnliftsStateForLocalMiddleware() {
        let nameMiddleware = IsoMiddlewareMock<AppAction.Bar, String>()
        let context = MiddlewareContextMock<AppAction, TestState>()
        context.state = TestState(value: .init(), name: "test-unlift-state")
        let generalMiddleware: LiftMiddleware<AppAction, AppAction, TestState, IsoMiddlewareMock<AppAction.Bar, String>> = nameMiddleware.lift(
            actionZoomIn: { $0.bar },
            actionZoomOut: { bar in .bar(bar) },
            stateZoomIn: { $0.name }
        )
        generalMiddleware.context = { context.value }

        XCTAssertEqual("test-unlift-state", nameMiddleware.context().getState())
    }
}
