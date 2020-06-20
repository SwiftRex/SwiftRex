extension MiddlewareReaderProtocol where MiddlewareType: Semigroup {
    /// Compose two Semigroup Middlewares into one, before even materializing them into real instances.
    /// - Parameters:
    ///   - lhs: middleware reader that will generate a middleware which runs first
    ///   - rhs: middleware reader that will generate a middleware which runs last
    /// - Returns: a composed Middleware Reader that, once injected with dependencies, will produce a middleware that runs first the left and then
    ///            the right middleware
    public static func <> (lhs: Self, rhs: Self) -> Self {
        .init { dependencies in
            lhs.inject(dependencies) <> rhs.inject(dependencies)
        }
    }
}
extension MiddlewareReader: Semigroup where MiddlewareType: Semigroup { }

extension MiddlewareReaderProtocol {
    /// Compose two Middlewares that are not officially Semigroups and not necessarily the same Middleware type, into a `ComposedMiddleware` that
    /// holds both before even materializing them into real instances.
    /// As most Middlewares don't need to return `Self` when grouped together, and it's perfectly reasonable to compose middlewares of different
    /// types, this option is more flexible than the Semigroup composition.
    ///
    /// The only requirements are that:
    /// - both middleware readers must depend on the same Dependencies type
    /// - both resulting middlewares should match their input action, output action and state types
    ///
    /// Therefore, you should lift them first before composing them. Luckily this is possible to be done with MiddlewareReader.
    ///
    /// - Parameters:
    ///   - lhs: middleware reader that will generate a middleware which runs first
    ///   - rhs: middleware reader that will generate a middleware which runs last
    /// - Returns: a composed Middleware Reader that, once injected with dependencies, will produce a ComposedMiddleware that runs first the left and
    ///            then the right middleware
    public static func <> <OtherMiddleware: Middleware>(lhs: Self, rhs: MiddlewareReader<Dependencies, OtherMiddleware>)
    -> MiddlewareReader<Dependencies, ComposedMiddleware<MiddlewareType.InputActionType, MiddlewareType.OutputActionType, MiddlewareType.StateType>>
        where
        OtherMiddleware.InputActionType == MiddlewareType.InputActionType,
        OtherMiddleware.OutputActionType == MiddlewareType.OutputActionType,
        OtherMiddleware.StateType == MiddlewareType.StateType {
        zip(lhs, rhs, with: <>)
    }
}
