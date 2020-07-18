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
            handle: { globalInputAction, globalState, globalContext -> Effect<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map { $0.map(outputActionMap) }.asEffect()
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { globalInputAction, state, globalContext -> Effect<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    state,
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map { $0.map(outputActionMap) }.asEffect()
            }
        )
    }

    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { globalInputAction, globalState, globalContext -> Effect<OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).asEffect()
            }
        )
    }

    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { inputAction, globalState, globalContext -> Effect<GlobalOutputActionType> in
                self.onAction(
                    inputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map { $0.map(outputActionMap) }.asEffect()
            }
        )
    }

    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?
    ) -> EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware<GlobalInputActionType, OutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { globalInputAction, state, globalContext -> Effect<OutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    state,
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).asEffect()
            }
        )
    }

    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType
    ) -> EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies> {
        EffectMiddleware<InputActionType, GlobalOutputActionType, StateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { inputAction, state, globalContext -> Effect<GlobalOutputActionType> in
                self.onAction(
                    inputAction,
                    state,
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map { $0.map(outputActionMap) }.asEffect()
            }
        )
    }

    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> StateType
    ) -> EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<InputActionType, OutputActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { inputAction, globalState, globalContext -> Effect<OutputActionType> in
                self.onAction(
                    inputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).asEffect()
            }
        )
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where InputAction == OutputAction {
    public func lift<GlobalActionType, GlobalStateType>(
        action actionMap: WritableKeyPath<GlobalActionType, InputAction?>,
        state stateMap: KeyPath<GlobalStateType, StateType>
    ) -> EffectMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, Dependencies> {
        EffectMiddleware<GlobalActionType, GlobalActionType, GlobalStateType, Dependencies>(
            dependencies: self.dependencies,
            handle: { globalInputAction, globalState, globalContext -> Effect<GlobalActionType> in
                guard let localInputAction = globalInputAction[keyPath: actionMap] else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    globalState[keyPath: stateMap],
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: globalContext.dependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map { localEffectOutput in
                    localEffectOutput.map { localOutputAction in
                        var globalAction = globalInputAction
                        globalAction[keyPath: actionMap] = localOutputAction
                        return globalAction
                    }
                }.asEffect()
            }
        )
    }
}
#endif
