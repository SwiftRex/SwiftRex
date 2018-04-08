import SwiftRex

class MiddlewareMock<StateType>: Middleware {
    var actionHandler: ActionHandler?

    // MARK: - handle

    var handleEventGetStateNextCallsCount = 0
    var handleEventGetStateNextCalled: Bool {
        return handleEventGetStateNextCallsCount > 0
    }
    var handleEventGetStateNextReceivedArguments: (event: EventProtocol, getState: GetState<StateType>, next: NextEventHandler<StateType>)?
    var handleEventGetStateNextClosure: ((EventProtocol, @escaping GetState<StateType>, @escaping NextEventHandler<StateType>) -> Void)?

    func handle(event: EventProtocol, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) {
        handleEventGetStateNextCallsCount += 1
        handleEventGetStateNextReceivedArguments = (event: event, getState: getState, next: next)
        handleEventGetStateNextClosure?(event, getState, next)
    }

    // MARK: - handle

    var handleActionGetStateNextCallsCount = 0
    var handleActionGetStateNextCalled: Bool {
        return handleActionGetStateNextCallsCount > 0
    }
    var handleActionGetStateNextReceivedArguments: (action: ActionProtocol, getState: GetState<StateType>, next: NextActionHandler<StateType>)?
    var handleActionGetStateNextClosure: ((ActionProtocol, @escaping GetState<StateType>, @escaping NextActionHandler<StateType>) -> Void)?

    func handle(action: ActionProtocol, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) {
        handleActionGetStateNextCallsCount += 1
        handleActionGetStateNextReceivedArguments = (action: action, getState: getState, next: next)
        handleActionGetStateNextClosure?(action, getState, next)
    }
}
