// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable line_length
// swiftlint:disable variable_name

import Foundation
import RxSwift
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif

class ActionHandlerMock: ActionHandler {

    // MARK: - trigger

    var triggerCallsCount = 0
    var triggerCalled: Bool {
        return triggerCallsCount > 0
    }
    var triggerReceivedAction: ActionProtocol?
    var triggerClosure: ((ActionProtocol) -> Void)?

    func trigger(_ action: ActionProtocol) {
        triggerCallsCount += 1
        triggerReceivedAction = action
        triggerClosure?(action)
    }

}
class MiddlewareMock: Middleware {
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
class SideEffectProducerMock: SideEffectProducer {

    // MARK: - execute

    var executeGetStateCallsCount = 0
    var executeGetStateCalled: Bool {
        return executeGetStateCallsCount > 0
    }
    var executeGetStateReceivedGetState: GetState<StateType>?
    var executeGetStateReturnValue: Observable<ActionProtocol>!
    var executeGetStateClosure: ((@escaping GetState<StateType>) -> Observable<ActionProtocol>)?

    func execute(getState: @escaping GetState<StateType>) -> Observable<ActionProtocol> {
        executeGetStateCallsCount += 1
        executeGetStateReceivedGetState = getState
        return executeGetStateClosure.map({ $0(getState) }) ?? executeGetStateReturnValue
    }

}
