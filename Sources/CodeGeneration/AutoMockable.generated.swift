// Generated using Sourcery 0.10.1 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable line_length
// swiftlint:disable variable_name

import Foundation
import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif













class MiddlewareMock: Middleware {

    //MARK: - handle

    var handleEventGetStateNextCallsCount = 0
    var handleEventGetStateNextCalled: Bool {
        return handleEventGetStateNextCallsCount > 0
    }
    var handleEventGetStateNextReceivedArguments: (event: Event, getState: () -> StateType, next: (Event, @escaping () -> StateType) -> Void)?
    var handleEventGetStateNextClosure: ((Event, @escaping () -> StateType, @escaping (Event, @escaping () -> StateType) -> Void) -> Void)?

    func handle(event: Event, getState: @escaping () -> StateType, next: @escaping (Event, @escaping () -> StateType) -> Void) {
        handleEventGetStateNextCallsCount += 1
        handleEventGetStateNextReceivedArguments = (event: event, getState: getState, next: next)
        handleEventGetStateNextClosure?(event, getState, next)
    }

    //MARK: - handle

    var handleActionGetStateNextCallsCount = 0
    var handleActionGetStateNextCalled: Bool {
        return handleActionGetStateNextCallsCount > 0
    }
    var handleActionGetStateNextReceivedArguments: (action: Action, getState: () -> StateType, next: (Action, @escaping () -> StateType) -> Void)?
    var handleActionGetStateNextClosure: ((Action, @escaping () -> StateType, @escaping (Action, @escaping () -> StateType) -> Void) -> Void)?

    func handle(action: Action, getState: @escaping () -> StateType, next: @escaping (Action, @escaping () -> StateType) -> Void) {
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
