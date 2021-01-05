// swiftlint:disable file_length

// MARK: - Map 4
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<GlobalDependencies, LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, MiddlewareType>> {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: inputActionMap,
                        outputAction: outputActionMap,
                        state: stateMap)
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: - Map 3

// MARK: No input action map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<MiddlewareType.InputActionType, GlobalOutputActionType, GlobalStateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: { $0 },
                        outputAction: outputActionMap,
                        state: stateMap)
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: No output action map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<GlobalInputActionType, MiddlewareType.OutputActionType, GlobalStateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: inputActionMap,
                        outputAction: { $0 },
                        state: stateMap)
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: No state map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, MiddlewareType.StateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: inputActionMap,
                        outputAction: outputActionMap,
                        state: { $0 })
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: No dependencies map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalInputActionType, GlobalOutputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType
    ) -> MiddlewareReader<Dependencies, LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, GlobalStateType, MiddlewareType>> {
        mapMiddleware {
            $0.lift(inputAction: inputActionMap,
                    outputAction: outputActionMap,
                    state: stateMap)
        }
    }
}

// MARK: - Map 2

// MARK: State and Dependencies map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<MiddlewareType.InputActionType, MiddlewareType.OutputActionType, GlobalStateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: { $0 },
                        outputAction: { $0 },
                        state: stateMap)
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: Output action and Dependencies map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<MiddlewareType.InputActionType, GlobalOutputActionType, MiddlewareType.StateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: { $0 },
                        outputAction: outputActionMap,
                        state: { $0 })
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: Output action and State map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalOutputActionType, GlobalStateType>(
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType
    ) -> MiddlewareReader<Dependencies, LiftMiddleware<MiddlewareType.InputActionType, GlobalOutputActionType, GlobalStateType, MiddlewareType>> {
        mapMiddleware {
            $0.lift(inputAction: { $0 },
                    outputAction: outputActionMap,
                    state: stateMap)
        }
    }
}

// MARK: Input action and Dependencies map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies, GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<
        GlobalDependencies,
        LiftMiddleware<GlobalInputActionType, MiddlewareType.OutputActionType, MiddlewareType.StateType, MiddlewareType>
    > {
        dimap(
            transformMiddleware: {
                $0.lift(inputAction: inputActionMap,
                        outputAction: { $0 },
                        state: { $0 })
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

// MARK: Input action and State map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalInputActionType, GlobalStateType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType
    ) -> MiddlewareReader<Dependencies, LiftMiddleware<GlobalInputActionType, MiddlewareType.OutputActionType, GlobalStateType, MiddlewareType>> {
        mapMiddleware {
            $0.lift(inputAction: inputActionMap,
                    outputAction: { $0 },
                    state: stateMap)
        }
    }
}

// MARK: Input action and Output action map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalInputActionType, GlobalOutputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?,
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType
    ) -> MiddlewareReader<Dependencies, LiftMiddleware<GlobalInputActionType, GlobalOutputActionType, MiddlewareType.StateType, MiddlewareType>> {
        mapMiddleware {
            $0.lift(inputAction: inputActionMap,
                    outputAction: outputActionMap,
                    state: { $0 })
        }
    }
}

// MARK: - Map 1

// MARK: State map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - stateMap: this middleware may read only small portions of the whole app state. Global App State will be given so you can pick only the
    ///               parts relevant for this middleware. This is usually implemented like:
    ///               ```
    ///               stateMap: { globalState in
    ///                   return globalState.someProperty
    ///               }
    ///               ```
    ///               Or the KeyPath form: `stateMap: \AppState.someProperty`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalStateType>(
        state stateMap: @escaping (GlobalStateType) -> MiddlewareType.StateType
    ) -> MiddlewareReader<
        Dependencies,
        LiftMiddleware<MiddlewareType.InputActionType, MiddlewareType.OutputActionType, GlobalStateType, MiddlewareType>
    > {
        mapMiddleware {
            $0.lift(inputAction: { $0 },
                    outputAction: { $0 },
                    state: stateMap)
        }
    }
}

// MARK: Dependencies map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - dependenciesMap: this middleware may depend on only a small amount of dependencies, not all the dependencies in your app. Given that
    ///                      there's a `GlobalDependencies` struct holding the whole world of dependencies, this function can pick only the
    ///                      dependencies needed for this middleware. This is usually implemented like:
    ///                      ```
    ///                      dependenciesMap: { (world: World) in
    ///                          return (urlSession: world.urlSession, decoder: world.jsonDecoder)
    ///                      }
    ///                      ```
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalDependencies>(
        dependencies dependenciesMap: @escaping (GlobalDependencies) -> Dependencies
    ) -> MiddlewareReader<GlobalDependencies, MiddlewareType> {
        contramapDependecies(dependenciesMap)
    }
}

// MARK: Output action map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - outputActionMap: once this middleware dispatched some actions, this function should tell how to wrap each action to a more global action
    ///                      entity, to be forwarded to the Store chain. This is usually implemented like:
    ///                      ```
    ///                      outputActionMap: { actionFromMiddleware in
    ///                          return AppAction.someLocalCase(actionFromMiddleware)
    ///                      }
    ///                      ```
    ///                      Or for a single-level enum, the short-form `outputActionMap: AppAction.someLocalCase`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalOutputActionType>(
        outputAction outputActionMap: @escaping (MiddlewareType.OutputActionType) -> GlobalOutputActionType
    ) -> MiddlewareReader<
        Dependencies,
        LiftMiddleware<MiddlewareType.InputActionType, GlobalOutputActionType, MiddlewareType.StateType, MiddlewareType>
    > {
        mapMiddleware {
            $0.lift(inputAction: { $0 },
                    outputAction: outputActionMap,
                    state: { $0 })
        }
    }
}

// MARK: Input action map
extension MiddlewareReaderProtocol {
    /// All you need to compose totally different middlewares. Using lift you can match all 4 parameters of a middleware and once they have common
    /// ground, you are able to compose them. These 4 parameters are:
    /// - Input Actions for the Middleware
    /// - Output Actions from the Middleware
    /// - Input State for the Middleware
    /// - Input Dependencies for the Middleware, through its MiddlewareReader dependency injection.
    ///
    /// - Parameters:
    ///   - inputActionMap: once app actions (global) are in the Store chain, this function will pick only those that are relevant for this middleware
    ///                     or return nil in case they should be ignored. Global Actions that can be transformed into local actions will be forwarded
    ///                     to the middleware. This is usually implemented like:
    ///                     ```
    ///                     inputActionMap: { globalAction in
    ///                         guard case let AppAction.someLocalCase(localAction) = globalAction else { return nil }
    ///                         return localAction
    ///                     }
    ///                     ```
    ///                     You can use enum properties code generators to simplify this call to a simple `inputActionMap: \AppAction.someLocalCase`
    /// - Returns: a `MiddlewareReader` that works on global types, so it can be composed with other MiddlewareReaders matching same global types
    ///            even before injecting the dependencies.
    public func lift<GlobalInputActionType>(
        inputAction inputActionMap: @escaping (GlobalInputActionType) -> MiddlewareType.InputActionType?
    ) -> MiddlewareReader<
        Dependencies,
        LiftMiddleware<GlobalInputActionType, MiddlewareType.OutputActionType, MiddlewareType.StateType, MiddlewareType>
    > {
        mapMiddleware {
            $0.lift(inputAction: inputActionMap,
                    outputAction: { $0 },
                    state: { $0 })
        }
    }
}
