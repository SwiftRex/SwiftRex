extension MiddlewareReaderProtocol {
    /// Wraps a pure function in a `MiddlewareReader` container just for the sake of composition. Nothing is actually needed for the calculation and
    /// injected dependency will be ignored. This is useful for lifting a `Middleware` into a `MiddlewareReader`, so you can compose with other
    /// MiddlewareReaders that actually depend on dependencies.
    /// - Parameter value: The middleware that will be eventually returned when "inject" is called. This is a autoclosure so it can be lazily
    ///                    evaluated.
    /// - Returns: a `MiddlewareReader` that wraps the given Middleware until `inject` is called.
    public static func pure(_ value: MiddlewareType) -> Self {
        Self { _ in value }
    }
}
