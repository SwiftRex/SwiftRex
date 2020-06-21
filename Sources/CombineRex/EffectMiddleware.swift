#if canImport(Combine)
import Combine
import Foundation
import SwiftRex

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias SymmetricalEffectMiddleware<Action, State, Dependencies> = EffectMiddleware<Action, Action, State, Dependencies>

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class EffectMiddleware<InputAction, OutputAction, State, Dependencies>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: AnyCancellable]()
    private var cancellableButNotViaToken = Set<AnyCancellable>()
    private var onAction: (InputActionType, StateType, Context) -> Effect<OutputActionType>
    private var dependencies: Dependencies

    public struct Context {
        public let dispatcher: ActionSource
        public let dependencies: Dependencies
        public let toCancel: (AnyHashable) -> Void
    }

    private init(
        dependencies: Dependencies,
        handle: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) {
        self.dependencies = dependencies
        self.onAction = handle
    }

    private var getState: GetState<StateType>?
    private var output: AnyActionHandler<OutputActionType>?
    public func receiveContext(getState: @escaping GetState<StateType>, output: AnyActionHandler<OutputActionType>) {
        self.getState = getState
        self.output = output
    }

    public func handle(action: InputActionType, from dispatcher: ActionSource, afterReducer: inout AfterReducer) {
        afterReducer = .do { [weak self] in
            guard let self = self else { return }
            guard let state = self.getState?() else { return }
            let context = Context(dispatcher: dispatcher, dependencies: self.dependencies) { [weak self] cancellingToken in
                self?.cancellables.removeValue(forKey: cancellingToken)
            }
            let effect = self.onAction(action, state, context)
            self.run(effect: effect)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> MiddlewareReader<Dependencies, EffectMiddleware> {
        MiddlewareReader { dependencies in
            EffectMiddleware(dependencies: dependencies, handle: handler)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware where Dependencies == Void {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware(dependencies: ()) { action, state, context in
            handler(action, state, context)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    private func run(effect: Effect<OutputAction>) {
        let subscription = effect
            .sink(receiveValue: { [weak self] in self?.output?.dispatch($0) })

        if let token = effect.cancellationToken {
            cancellables[token] = subscription
        } else {
            subscription.store(in: &cancellableButNotViaToken)
        }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware: Semigroup {
    public static func <> (lhs: EffectMiddleware, rhs: EffectMiddleware) -> EffectMiddleware {
        Self.onAction { action, state, context -> Effect<OutputActionType> in
            let leftEffect = lhs.onAction(
                action,
                state,
                Context(
                    dispatcher: context.dispatcher,
                    dependencies: lhs.dependencies,
                    toCancel: context.toCancel
                )
            )
            let rightEffect = rhs.onAction(
                action,
                state,
                Context(
                    dispatcher: context.dispatcher,
                    dependencies: rhs.dependencies,
                    toCancel: context.toCancel
                )
            )
            return leftEffect.merge(with: rightEffect).asEffect
        }.inject(lhs.dependencies)
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware: Monoid where Dependencies == Void {
    public static var identity: EffectMiddleware<InputAction, OutputAction, State, Dependencies> {
        Self.onAction { _, _, _ in .doNothing }
    }
}

@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
extension EffectMiddleware {
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, GlobalDependencies>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> InputActionType?,
        outputAction outputActionMap: @escaping (OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> StateType,
        dependencies dependenciesMap: @escaping (Dependencies) -> GlobalDependencies
    ) -> EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, GlobalDependencies> {
        let localDependencies = self.dependencies

        return EffectMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, GlobalDependencies>(
            dependencies: dependenciesMap(localDependencies),
            handle: { globalInputAction, globalState, globalContext -> Effect<GlobalOutputActionType> in
                guard let localInputAction = inputActionMap(globalInputAction) else { return .doNothing }
                return self.onAction(
                    localInputAction,
                    stateMap(globalState),
                    Context(
                        dispatcher: globalContext.dispatcher,
                        dependencies: localDependencies,
                        toCancel: globalContext.toCancel
                    )
                ).map(outputActionMap).asEffect
            }
        )
    }
}
#endif
