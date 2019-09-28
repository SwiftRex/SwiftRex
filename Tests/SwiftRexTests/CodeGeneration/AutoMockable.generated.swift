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
    var context: (() -> MiddlewareContext<ActionType, StateType>) {
        get { return underlyingContext }
        set(value) { underlyingContext = value }
    }
    var underlyingContext: (() -> MiddlewareContext<ActionType, StateType>)!

    //MARK: - handle

    var handleActionCallsCount = 0
    var handleActionCalled: Bool {
        return handleActionCallsCount > 0
    }
    var handleActionReceivedAction: ActionType?
    var handleActionClosure: ((ActionType) -> Void)?

    func handle(action: ActionType) {
        handleActionCallsCount += 1
        handleActionReceivedAction = action
        handleActionClosure?(action)
    }

}
