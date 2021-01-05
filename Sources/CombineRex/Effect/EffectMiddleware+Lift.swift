#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: { stateMap(getState()) }, output: output.contramap(outputActionMap))
            },
            onAction: { globalInputAction, dispatcher, globalState -> Effect<Dependencies, GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(localInputAction, dispatcher, { stateMap(globalState()) }).map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: getState, output: output.contramap(outputActionMap))
            },
            onAction: { globalInputAction, dispatcher, state -> Effect<Dependencies, GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(localInputAction, dispatcher, state).map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: { stateMap(getState()) }, output: output)
            },
            onAction: { globalInputAction, dispatcher, globalState -> Effect<Dependencies, OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(localInputAction, dispatcher, { stateMap(globalState()) })
            }
        )
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: { stateMap(getState()) }, output: output.contramap(outputActionMap))
            },
            onAction: { inputAction, dispatcher, globalState -> Effect<Dependencies, GlobalOutputActionType> in
                self.onAction(inputAction, dispatcher, { stateMap(globalState()) }).map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: getState, output: output)
            },
            onAction: { globalInputAction, dispatcher, state -> Effect<Dependencies, OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(localInputAction, dispatcher, state)
            }
        )
    }

    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: getState, output: output.contramap(outputActionMap))
            },
            onAction: { inputAction, dispatcher, state -> Effect<Dependencies, GlobalOutputActionType> in
                self.onAction(inputAction, dispatcher, state).map(outputActionMap)
            }
        )
    }

    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { getState, output in
                self.receiveContext(getState: { stateMap(getState()) }, output: output)
            },
            onAction: { inputAction, dispatcher, globalState -> Effect<Dependencies, OutputActionType> in
                self.onAction(inputAction, dispatcher, { stateMap(globalState()) })
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where InputActionType == OutputActionType {
    public func lift<GlobalActionType, GlobalStateType>(
        action actionMap: WritableKeyPath<GlobalActionType, InputActionType?>,
        state stateMap: KeyPath<GlobalStateType, StateType>
    ) -> EffectMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, Dependencies> {
        var hasTransferredContext = false
        var output: AnyActionHandler<GlobalActionType>?

        return EffectMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            onReceiveContext: { _, receivedOutput in
                output = receivedOutput
                hasTransferredContext = false
            },
            onAction: { globalInputAction, dispatcher, globalState -> Effect<Dependencies, GlobalActionType> in
                guard let localInputAction = globalInputAction[keyPath: actionMap],
                      let output = output else { return .doNothing }

                let contramapOutput: (OutputActionType) -> GlobalActionType = { localAction in
                    var mutableGlobal = globalInputAction
                    mutableGlobal[keyPath: actionMap] = localAction
                    return mutableGlobal
                }

                if !hasTransferredContext {
                    hasTransferredContext = true
                    self.receiveContext(getState: { globalState()[keyPath: stateMap] }, output: output.contramap(contramapOutput))
                }

                return self.onAction(localInputAction, dispatcher, { globalState()[keyPath: stateMap] }).map(contramapOutput)
            }
        )
    }
}
#endif
