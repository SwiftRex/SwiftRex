import Foundation
import ReactiveSwift
import SwiftRex

public typealias SimpleEffectMiddleware<Action, State> = EffectMiddleware<Action, Action, State, Void>

public typealias SymmetricalEffectMiddleware<Action, State, Dependencies> = EffectMiddleware<Action, Action, State, Dependencies>

public final class EffectMiddleware<InputAction, OutputAction, State, Dependencies>: Middleware {
    public typealias InputActionType = InputAction
    public typealias OutputActionType = OutputAction
    public typealias StateType = State

    private var cancellables = [AnyHashable: Lifetime.Token]()
    private var cancellableButNotViaToken = CompositeDisposable()
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

extension EffectMiddleware {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> MiddlewareReader<Dependencies, EffectMiddleware> {
        MiddlewareReader { dependencies in
            EffectMiddleware(dependencies: dependencies, handle: handler)
        }
    }
}

extension EffectMiddleware where Dependencies == Void {
    public static func onAction(
        do handler: @escaping (InputActionType, StateType, Context) -> Effect<OutputActionType>
    ) -> EffectMiddleware<InputActionType, OutputActionType, StateType, Dependencies> {
        EffectMiddleware(dependencies: ()) { action, state, context in
            handler(action, state, context)
        }
    }
}

extension EffectMiddleware {
    private func run(effect: Effect<OutputAction>) {
        let subscription = effect
            .producer.startWithValues { [weak self] in self?.output?.dispatch($0) }

        if let token = effect.cancellationToken {
            let (lifetime, lifetimeToken) = Lifetime.make()
            lifetime += subscription
            cancellables[token] = lifetimeToken
        } else {
            cancellableButNotViaToken += subscription
        }
    }
}

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
            return leftEffect.producer.merge(with: rightEffect.producer).asEffect
        }.inject(lhs.dependencies)
    }
}

extension EffectMiddleware: Monoid where Dependencies == Void {
    public static var identity: EffectMiddleware<InputAction, OutputAction, State, Dependencies> {
        Self.onAction { _, _, _ in .doNothing }
    }
}

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
                ).producer.map(outputActionMap).asEffect
            }
        )
    }
}
