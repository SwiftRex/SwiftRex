extension MiddlewareReaderProtocol where MiddlewareType: Monoid {
    /// An identity MiddlewareReader ignores whatever Dependencies are given and simply return an identity Middleware. Composing any given middleware
    /// reader "A" with the identity middleware reader will be exactly the same as composing in the other order and also exactly the same as only the
    /// middleware reader "A" alone, which means, it doesn't change anything in the MiddlewareReader "A" or its resulting Middleware, regardless of
    /// the order it was composed to.
    public static var identity: Self {
        .init { _ in .identity }
    }
}

extension MiddlewareReader: Monoid where MiddlewareType: Monoid { }

extension MiddlewareReaderProtocol {
    /// An identity MiddlewareReader ignores whatever Dependencies are given and simply return an identity Middleware. Composing any given middleware
    /// reader "A" with the identity middleware reader will be exactly the same as composing in the other order and also exactly the same as only the
    /// middleware reader "A" alone, which means, it doesn't change anything in the MiddlewareReader "A" or its resulting Middleware, regardless of
    /// the order it was composed to.
    public static var identity: MiddlewareReader<
        Self.Dependencies,
        IdentityMiddleware<Self.MiddlewareType.InputActionType, Self.MiddlewareType.OutputActionType, Self.MiddlewareType.StateType>
    > {
        .init { _ in IdentityMiddleware() }
    }
}
