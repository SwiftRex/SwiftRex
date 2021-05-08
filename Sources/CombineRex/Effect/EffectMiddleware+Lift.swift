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
            actionHandler: { globalInputAction, dispatcher, globalState -> IO<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .pure() }
                return self.handle(action: localInputAction, from: dispatcher, state: { stateMap(globalState()) })
                    .map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { globalInputAction, dispatcher, state -> IO<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .pure() }
                return self.handle(action: localInputAction, from: dispatcher, state: state)
                    .map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { globalInputAction, dispatcher, globalState -> IO<OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .pure() }
                return self.handle(action: localInputAction, from: dispatcher, state: { stateMap(globalState()) })
            }
        )
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { inputAction, dispatcher, globalState -> IO<GlobalOutputActionType> in
                self.handle(action: inputAction, from: dispatcher, state: { stateMap(globalState()) })
                    .map(outputActionMap)
            }
        )
    }

    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { globalInputAction, dispatcher, state -> IO<OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .pure() }
                return self.handle(action: localInputAction, from: dispatcher, state: state)
            }
        )
    }

    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { inputAction, dispatcher, state -> IO<GlobalOutputActionType> in
                self.handle(action: inputAction, from: dispatcher, state: state)
                    .map(outputActionMap)
            }
        )
    }

    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { inputAction, dispatcher, globalState -> IO<OutputActionType> in
                self.handle(action: inputAction, from: dispatcher, state: { stateMap(globalState()) })
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
        EffectMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            actionHandler: { globalInputAction, dispatcher, globalState -> IO<GlobalActionType> in
                guard let localInputAction = globalInputAction[keyPath: actionMap] else { return .pure() }

                let contramapOutput: (OutputActionType) -> GlobalActionType = { localAction in
                    var mutableGlobal = globalInputAction
                    mutableGlobal[keyPath: actionMap] = localAction
                    return mutableGlobal
                }

                return self.handle(action: localInputAction, from: dispatcher, state: { globalState()[keyPath: stateMap] })
                    .map(contramapOutput)
            }
        )
    }
}
#endif
