import Foundation

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
        mapMiddleware(transformMiddleware).contramapDependecies(extractOnlyDependenciesNeededForThisMiddleware)
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
