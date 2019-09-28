// Generated using Sourcery 0.17.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable all
import Foundation
@testable import SwiftRex
#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit
#elseif os(OSX)
import AppKit
#endif













class MiddlewareMock<StateType>: Middleware {
    var context: (() -> MiddlewareContext<StateType>) {
        get { return underlyingContext }
        set(value) { underlyingContext = value }
    }
    var underlyingContext: (() -> MiddlewareContext<StateType>)!

    //MARK: - handle

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

    //MARK: - handle

    var handleActionCallsCount = 0
    var handleActionCalled: Bool {
        return handleActionCallsCount > 0
    }
    var handleActionReceivedAction: ActionProtocol?
    var handleActionClosure: ((ActionProtocol) -> Void)?

    func handle(action: ActionProtocol) {
        handleActionCallsCount += 1
        handleActionReceivedAction = action
        handleActionClosure?(action)
    }

}
