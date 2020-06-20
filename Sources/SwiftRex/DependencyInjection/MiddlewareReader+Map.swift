import Foundation

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
                $0.lift(inputActionMap: inputActionMap,
                        outputActionMap: outputActionMap,
                        stateMap: stateMap)
            },
            extractOnlyDependenciesNeededForThisMiddleware: dependenciesMap
        )
    }
}

extension MiddlewareReaderProtocol {

    /// Maps the `Middleware` element that will eventually be produced upon dependency injection, and derives into a new `Middleware`
    ///
    /// - We start with a dependency `X` to calculate middleware `A`
    /// - We give a way for going from middleware `A` to middleware `B`
    /// - Our resulting mapped `MiddlewareReader` will accept dependency `X` to calculate middleware `B`
    /// - Dependency type hasn't changed at all
    ///
    /// - Parameter transform: function that transforms original produced Middleware into a new one, once the dependencies are injected
    /// - Returns: a new `MiddlewareReader` that will create not the original MiddlewareType any more, but a NewMiddleware mapped from the original
    public func mapMiddleware<NewMiddleware: Middleware>(_ transform: @escaping (MiddlewareType) -> NewMiddleware)
    -> MiddlewareReader<Dependencies, NewMiddleware> {
        MiddlewareReader<Dependencies, NewMiddleware> { environment in
            transform(self.inject(environment))
        }
    }

    /// Maps the `Dependencies` element, which is the input environment of the calculation for a particular middleware, using a contravariant
    /// function that will allow to lift this reader into a `MiddlewareReader` compatible with a more global dependencies structure.
    ///
    /// Once this `MiddlewareReader` is lifted to depend on `World` (where world means all dependencies you need for all middlewares), it can be
    /// combined with others that also depend on the same `World`, so this is useful for composition as you eventually want to combine all sorts of
    /// middlewares that have different dependencies, so this is for finding a common ground for all of them.
    ///
    /// - We start with a local dependency `X` to calculate middleware `A`
    /// - We give a way to extract depdendency `X` from world `W` (`W` -> `X`), where world means all dependencies you need for all middlewares
    /// - Our resulting `MiddlewareReader` will accept dependency `W` to calculate middleware `A`
    /// - Middleware type hasn't changed at all
    ///
    /// - Parameter extractOnlyDependenciesNeededForThisMiddleware: given all dependencies in the World of this app, that are needed for all
    ///                                                             middlewares and not only this one, extracts only what we need for this one
    /// - Returns: a new `MiddlewareReader` that will require the full `World` to create the `MiddlewareType`. It can be combined with others that
    ///            also depend on the same `World`, so this is useful for composition as you eventually want to combine all sorts of middlewares that
    ///            have different dependencies, so this is for finding a common ground for all of them.
    public func contramapDependecies<World>(_ extractOnlyDependenciesNeededForThisMiddleware: @escaping (World) -> Dependencies)
    -> MiddlewareReader<World, MiddlewareType> {
        MiddlewareReader<World, MiddlewareType> { world in
            self.inject(extractOnlyDependenciesNeededForThisMiddleware(world))
        }
    }

    /// Maps the `Middleware` element that will eventually be produced upon dependency injection, and derives into a new `Middleware`
    ///
    /// Also maps the `Dependencies` element, which is the input environment of the calculation for a particular middleware, using a contravariant
    /// function that will allow to lift this reader into a `MiddlewareReader` compatible with a more global dependencies structure.
    ///
    /// Once this `MiddlewareReader` is lifted to depend on `World` (where world means all dependencies you need for all middlewares), it can be
    /// combined with others that also depend on the same `World`, so this is useful for composition as you eventually want to combine all sorts of
    /// middlewares that have different dependencies, so this is for finding a common ground for all of them.
    ///
    /// - We start with a dependency `X` to calculate middleware `A`
    /// - We give a way for going from middleware `A` to middleware `B`
    /// - We also give a way to extract depdendency `X` from world `W` (`W` -> `X`), where world means all dependencies you need for all middlewares
    /// - Our resulting mapped `MiddlewareReader` will accept dependency `@` to calculate middleware `B`
    ///
    /// - Parameters:
    ///   - transformMiddleware: function that transforms original produced Middleware into a new one, once the dependencies are injected
    ///   - extractOnlyDependenciesNeededForThisMiddleware: given all dependencies in the World of this app, that are needed for all
    ///                                                     middlewares and not only this one, extracts only what we need for this one
    /// - Returns: a new `MiddlewareReader` that will require the full `World` to create not the original MiddlewareType any more, but a
    ///            NewMiddleware mapped from the original. It can be combined with others that also depend on the same `World`, so this is useful for
    ///            composition as you eventually want to combine all sorts of middlewares that have different dependencies, so this is for finding a
    ///            common ground for all of them.
    public func dimap<NewMiddleware: Middleware, World>(transformMiddleware: @escaping (MiddlewareType) -> NewMiddleware,
                                                        extractOnlyDependenciesNeededForThisMiddleware: @escaping (World) -> Dependencies)
    -> MiddlewareReader<World, NewMiddleware> {
        return mapMiddleware(transformMiddleware).contramapDependecies(extractOnlyDependenciesNeededForThisMiddleware)
    }
}

extension MiddlewareReaderProtocol {
    /// Having a MiddlewareReader mapping that results in another MiddlewareReader that also depends on same environment, we can flatten up
    /// the map by using the same environment to inject in both MiddlewareReaders. Useful when there's a chain of dependencies
    /// - Parameter transform: a function that, from the produced middleware of the original middleware reader, can create another middleware reader
    ///                        that produces a different middleware, as long as their dependencies are the same
    /// - Returns: a flatten `MiddlewareReader` with transformation applied and dependencies injected in the original middleware reader, the produced
    ///            middleware given to the transform function and injected again.
    public func flatMap<NewMiddlewareReader: MiddlewareReaderProtocol>(_ transform: @escaping (MiddlewareType) -> NewMiddlewareReader)
    -> NewMiddlewareReader where NewMiddlewareReader.Dependencies == Dependencies {
        NewMiddlewareReader { environment in
            transform(self.inject(environment)).inject(environment)
        }
    }
}
