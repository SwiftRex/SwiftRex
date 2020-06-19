import Foundation

public struct MiddlewareReader<Dependencies, M: Middleware> {
    public let inject: (Dependencies) -> M

    public init(inject: @escaping (Dependencies) -> M) {
        self.inject = inject
    }
}

extension MiddlewareReader: Semigroup where M: Semigroup {
    public static func <> (lhs: MiddlewareReader, rhs: MiddlewareReader) -> MiddlewareReader {
        .init { dependencies in
            lhs.inject(dependencies) <> rhs.inject(dependencies)
        }
    }
}

extension MiddlewareReader {
    public static func <> (lhs: MiddlewareReader, rhs: MiddlewareReader)
    -> MiddlewareReader<Dependencies, ComposedMiddleware<M.InputActionType, M.OutputActionType, M.StateType>> {
        .init { dependencies in
            lhs.inject(dependencies) <> rhs.inject(dependencies)
        }
    }
}

extension MiddlewareReader: Monoid where M: Monoid {
    public static var identity: MiddlewareReader {
        .init { _ in .identity }
    }
}

extension MiddlewareReader {
    public func lift<GlobalDependencies, GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> M.InputActionType?,
        outputAction outputActionMap: @escaping (M.OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> M.StateType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<GlobalDependencies, LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, M>> {
        .init { globalDependencies in
            self.inject(dependenciesMap(globalDependencies))
                .lift(inputActionMap: inputActionMap,
                      outputActionMap: outputActionMap,
                      stateMap: stateMap)
        }
    }
}
