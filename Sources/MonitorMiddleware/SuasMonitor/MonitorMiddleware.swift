//
//  MonitorMiddleware.swift
//  Suas
//
//  Created by Omar Abdelhafith on 20/07/2017.
//  Copyright © 2017 Zendesk. All rights reserved.
//

import Foundation
import SwiftRex

struct ConnectedToMonitor: ActionProtocol, Encodable {
}

private let closingPlaceholder = "&&__&&__&&"

/// Block used to convert a type to a Dictionary to be transferred over the network to Suas Monitor desktop app
public typealias EncodingCallback<Type> = (Type) -> [String: Any]?

/// Middleware that transmits the state and actions to the Suas Monitor mac app
/// Get the latest version from https://github.com/zendesk/Suas-monitor/releases
///
/// MonitorMiddleware needs to convert actions and states to [String: Any] so that it can transmit them to the `SuasMonitor` mac app. That can be done with:
/// - Implement `SuasEncodable` in your Actions and States. `MonitorMiddleware` will use this protocol to convert the action and state to [String: Any]
/// - OR implement `stateEncoder` and `actionEncoder`: `MonitorMiddleware` will call these callbacks passing the state and action. The callbacks inturn have to return a `[String: Any]`
///
/// `MonitorMiddleware` Encoding behaviour:
/// - First, MonitorMiddleware will try to cast the state or action to `SuasEncodable`. If your state/action implement the `SuasEncodable` protocol, then Monitor will use that to convert them to JSON for transmission.
/// - If the state or action does not implement `SuasEncodable`, the middleware will use the `stateEncoder` and `actionEncoder`. The middleware will call these blocks with the state/action to get back a dictionary. The converted dictionary will be used by the middleware for transmission to the desktop app.
/// - Finally, if none of the above works. The middleware will use the state or action debug description as the string to transmit to the monitor desktop app.
///
/// # Note about swift 3.2+
/// In Swift 3.2 and newer versions you can implement `SuasEncodable` in your state types without writing code. `SuasEncodable` uses Swfit's `Econdable` protocol behind the scene.
///
/// # Examples
///
/// ## Implementing SuasEncodable manually (pre swift 3.2)
///
/// Types that implement `SuasEncodable` will be transmitted to the Suas Monitor desktop app
///
/// ```
/// struct MyState: SuasEncodable {
///   let value: Int
///
///   func toDictionary() -> [String : Any] {
///     return [
///       "value": value
///     ]
///   }
/// }
/// ```
///
/// ## Implementing SuasEncodable automatically (swift 3.2 and newer)
///
/// There is no code needed to implement `SuasEncodable` in your types in swift 3.2 and newer
///
/// ```
/// struct MyState: SuasEncodable {
///   let value: Int
/// }
/// ```
///
/// ## Use stateEncoder and actionEncoder
///
/// You can pass a stateEncoder and/or an actionEncoder to be used when converting states and/or actions to dictionaries for transmission
///
/// ```
/// let middleware = MonitorMiddleware(
///   stateEncoder: { state in
///     if let state = state as? CounterState {
///       // return dictionary
///     }
///     if let state = state as? OtherState {
///       // return dictionary
///     }
///   },
///   actionEncoder: { action in
///     if let action = action as? IncrementAction {
///       // return dictionary
///     }
///     if let action = action as? DecrementAction {
///       // return dictionary
///     }
///   },
/// )
///
/// // Use the middleware
/// let store = Suas.createStore(reducer: TodoReducer(),
///                              middleware: middleware)
/// ```
public class MonitorMiddleware<GlobalState>: Middleware {
    public var actionHandler: ActionHandler?

    public typealias StateType = GlobalState

    private var monitorService: MonitorService?

    private let  debugOnly: Bool
    private var stateEncoder: EncodingCallback<Any>?
    private var actionEncoder: EncodingCallback<ActionProtocol>?

    /// Create a MonitorMiddleware
    ///
    /// - Parameters:
    ///   - debugOnly: start the monitor in debug mode only (optional, defaults starting the monitor in debug only configuration)
    ///   - stateEncoder: (optional) callback that converts a state type to [String: Any].
    ///   - actionEncoder: (optional) callback that converts an action type to [String: Any]
    public convenience init(debugOnly: Bool = true,
                            stateEncoder: EncodingCallback<Any>? = nil,
                            actionEncoder: EncodingCallback<ActionProtocol>? = nil) {
        self.init(debugOnly: debugOnly,
                  stateEncoder: stateEncoder,
                  actionEncoder: actionEncoder,
                  monitorService: nil)
    }

    init(debugOnly: Bool = true,
         stateEncoder: EncodingCallback<Any>? = nil,
         actionEncoder: EncodingCallback<ActionProtocol>? = nil,
         monitorService: MonitorService?) {

        // Set up vars with nils as a performance step when monitor is disabled (release or debug only)
        self.stateEncoder = nil
        self.actionEncoder = nil
        self.monitorService = nil

        self.debugOnly = debugOnly

        if isRelease() && debugOnly {
            // In release configuration skip
            return
        }

        self.stateEncoder = stateEncoder
        self.actionEncoder = actionEncoder

        let name = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        self.monitorService = monitorService ?? DefaultMonitorService(displayName: name)

        self.monitorService?.start { [weak self] in
            self?.sendInitialState()
        }
    }

    public func handle(event: EventProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextEventHandler<GlobalState>) {
        next(event, getState)
    }

    public func handle(action: ActionProtocol, getState: @escaping GetState<GlobalState>, next: @escaping NextActionHandler<GlobalState>) {

        if isRelease() && debugOnly {
            // In release configuration skip
            next(action, getState)
            return
        }

        if !(action is ConnectedToMonitor) {
            next(action, getState)
        }

        sendToMonitor(state: getState(), action: action)
    }

    private func sendInitialState() {
        actionHandler?.trigger(ConnectedToMonitor())
    }

    private func sendToMonitor(state: GlobalState, action: ActionProtocol) {

        let dictionaryToSend: [String: Any] = [
            "action": "\(type(of: action))",
            "actionData": dictionary(forAction: action),
            "state": dictionary(forState: state)
        ]

        var data = try! JSONSerialization.data(withJSONObject: dictionaryToSend, options: [])
        data.append(closingPlaceholder.data(using: .utf8)!)

        monitorService?.send(data: data)
    }

    private func dictionary(forState state: GlobalState) -> [String: Any] {
        var stateToSend: [String: Any] = [:]

        if let encodableValue = state as? Encodable {
            return encodableValue.toDictionary()
        } else if let callback = stateEncoder, let stateValue = callback(state) {
            return stateValue
        } else {
            stateToSend["debugDescription"] = "\(state)"
            logString([
                "State with key: debugDescription",
                "Value: \(String(describing: state))",
                "does not implement `Encodable`. Using type debug description as value instead."
                ].joined(separator: "\n"))
        }

        return stateToSend
    }

    private func dictionary(forAction action: ActionProtocol) -> [String: Any] {
        if let action = action as? Encodable {
            return action.toDictionary()
        }

        if let callback = actionEncoder, let dict = callback(action) {
            return dict
        }

        logError(("Action", "actionEncoder", action))
        logString("-> Sending action debug description instead")

        return ["action": "\(action)"]
    }

    private func isRelease() -> Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
}
