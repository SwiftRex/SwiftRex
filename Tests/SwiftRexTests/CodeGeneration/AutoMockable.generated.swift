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













class ActionHandlerMock<ActionType>: ActionHandler {

    //MARK: - dispatch

    var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    var dispatchReceivedAction: ActionType?
    var dispatchClosure: ((ActionType) -> Void)?

    func dispatch(_ action: ActionType) {
        dispatchCallsCount += 1
        dispatchReceivedAction = action
        dispatchClosure?(action)
    }

}
class MiddlewareMock<InputActionType, OutputActionType, StateType>: Middleware {
    var context: (() -> MiddlewareContext<OutputActionType, StateType>) {
        get { return underlyingContext }
        set(value) { underlyingContext = value }
    }
    var underlyingContext: (() -> MiddlewareContext<OutputActionType, StateType>)!

    //MARK: - handle

    var handleActionNextCallsCount = 0
    var handleActionNextCalled: Bool {
        return handleActionNextCallsCount > 0
    }
    var handleActionNextReceivedArguments: (action: InputActionType, next: Next)?
    var handleActionNextClosure: ((InputActionType, @escaping Next) -> Void)?

    func handle(action: InputActionType, next: @escaping Next) {
        handleActionNextCallsCount += 1
        handleActionNextReceivedArguments = (action: action, next: next)
        handleActionNextClosure?(action, next)
    }

}
class ReduxStoreProtocolMock<ActionType, StateType>: ReduxStoreProtocol {
    var pipeline: ReduxPipelineWrapper<MiddlewareType> {
        get { return underlyingPipeline }
        set(value) { underlyingPipeline = value }
    }
    var underlyingPipeline: ReduxPipelineWrapper<MiddlewareType>!
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
class StateProviderMock<StateType>: StateProvider {
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

}
class StoreTypeMock<StateType, ActionType>: StoreType {
    var statePublisher: UnfailablePublisherType<StateType> {
        get { return underlyingStatePublisher }
        set(value) { underlyingStatePublisher = value }
    }
    var underlyingStatePublisher: UnfailablePublisherType<StateType>!

    //MARK: - dispatch

    var dispatchCallsCount = 0
    var dispatchCalled: Bool {
        return dispatchCallsCount > 0
    }
    var dispatchReceivedAction: ActionType?
    var dispatchClosure: ((ActionType) -> Void)?

    func dispatch(_ action: ActionType) {
        dispatchCallsCount += 1
        dispatchReceivedAction = action
        dispatchClosure?(action)
    }

}
