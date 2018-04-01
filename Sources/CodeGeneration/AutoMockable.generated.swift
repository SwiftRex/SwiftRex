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

typealias Event = SwiftRex.Event












class ActionHandlerMock: ActionHandler {

    //MARK: - trigger

    var triggerCallsCount = 0
    var triggerCalled: Bool {
        return triggerCallsCount > 0
    }
    var triggerReceivedAction: Action?
    var triggerClosure: ((Action) -> Void)?

    func trigger(_ action: Action) {
        triggerCallsCount += 1
        triggerReceivedAction = action
        triggerClosure?(action)
    }

}
class MiddlewareMock: Middleware {
    var actionHandler: ActionHandler?

    //MARK: - handle

    var handleEventGetStateNextCallsCount = 0
    var handleEventGetStateNextCalled: Bool {
        return handleEventGetStateNextCallsCount > 0
    }
    var handleEventGetStateNextReceivedArguments: (event: Event, getState: GetState<StateType>, next: NextEventHandler<StateType>)?
    var handleEventGetStateNextClosure: ((Event, @escaping GetState<StateType>, @escaping NextEventHandler<StateType>) -> Void)?

    func handle(event: Event, getState: @escaping GetState<StateType>, next: @escaping NextEventHandler<StateType>) {
        handleEventGetStateNextCallsCount += 1
        handleEventGetStateNextReceivedArguments = (event: event, getState: getState, next: next)
        handleEventGetStateNextClosure?(event, getState, next)
    }

    //MARK: - handle

    var handleActionGetStateNextCallsCount = 0
    var handleActionGetStateNextCalled: Bool {
        return handleActionGetStateNextCallsCount > 0
    }
    var handleActionGetStateNextReceivedArguments: (action: Action, getState: GetState<StateType>, next: NextActionHandler<StateType>)?
    var handleActionGetStateNextClosure: ((Action, @escaping GetState<StateType>, @escaping NextActionHandler<StateType>) -> Void)?

    func handle(action: Action, getState: @escaping GetState<StateType>, next: @escaping NextActionHandler<StateType>) {
        handleActionGetStateNextCallsCount += 1
        handleActionGetStateNextReceivedArguments = (action: action, getState: getState, next: next)
        handleActionGetStateNextClosure?(action, getState, next)
    }

}
class ReducerMock: Reducer {

    //MARK: - reduce

    var reduceActionCallsCount = 0
    var reduceActionCalled: Bool {
        return reduceActionCallsCount > 0
    }
    var reduceActionReceivedArguments: (currentState: StateType, action: Action)?
    var reduceActionReturnValue: StateType!
    var reduceActionClosure: ((StateType, Action) -> StateType)?

    func reduce(_ currentState: StateType, action: Action) -> StateType {
        reduceActionCallsCount += 1
        reduceActionReceivedArguments = (currentState: currentState, action: action)
        return reduceActionClosure.map({ $0(currentState, action) }) ?? reduceActionReturnValue
    }

}
class SideEffectProducerMock: SideEffectProducer {

    //MARK: - execute

    var executeGetStateCallsCount = 0
    var executeGetStateCalled: Bool {
        return executeGetStateCallsCount > 0
    }
    var executeGetStateReceivedGetState: GetState<StateType>?
    var executeGetStateReturnValue: Observable<Action>!
    var executeGetStateClosure: ((@escaping GetState<StateType>) -> Observable<Action>)?

    func execute(getState: @escaping GetState<StateType>) -> Observable<Action> {
        executeGetStateCallsCount += 1
        executeGetStateReceivedGetState = getState
        return executeGetStateClosure.map({ $0(getState) }) ?? executeGetStateReturnValue
    }

}
