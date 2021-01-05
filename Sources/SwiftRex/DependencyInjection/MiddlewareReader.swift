/// A MiddlewareReader is a way to lazily inject dependencies into a Middleware. For example, you may want to compose multiple middlewares but from
/// a library, and in this library you don't have the dependencies to inject just yet, because these dependencies are only present in the main target.
/// That way, instead of creating the middlewares (which would require all the dependencies), you can wrap their initializers in a MiddlewareReader.
/// The middleware reader is not a middleware, is a a factory (in OOP terms) from `(Dependencies) -> MiddlewareType` (in FP approach). The benefit
/// of wrapping the middleware initializers in a MiddlewareReader is that, for all means, MiddlewareReaders can be composed as Middlewares, can be
/// lifted as Middlewares, but all of this without in fact creating the Middlewares.
/// Your library can then expose a single MiddlewareReader as public, and you keep all its middlewares as internal classes. From the main target you
/// compose this MiddlewareReader with other MiddlewareReaders coming from other libraries and from the main target itself. Somewhere where you create
/// the Store, you finally inject the dependencies at once and you materialize all your middlewares at the same time.
/// Remember that "inject then compose" is the same as "compose then inject", but while the former needs dependencies upfront, the latter is more
/// flexible for being lazy.
/// For those familiar with Functional Programming, this is similar to Reader Monad, but as SwiftRex recommends dependencies only on Middlewares,
/// this Reader works specifically with Middlewares.
public struct MiddlewareReader<Dependencies, MiddlewareType: Middleware>: MiddlewareReaderProtocol {
    /// An initializer function that, given the dependencies in the Middleware's init, will give the Middleware instance
    /// When inject is called, your MiddlewareReader materializes into a Middleware.
    public let inject: (Dependencies) -> MiddlewareType

    /// Allows to define a middleware initializer and store this initializer function until we have the dependencies to call it.
    /// This allows us to postpone the dependency injection and compose middlewares that are not even materialized yet.
    /// - Parameter inject: An initializer function that, given the dependencies in the Middleware's init, will give the Middleware instance
    ///                     When inject is called, your MiddlewareReader materializes into a Middleware.
    public init(inject: @escaping (Dependencies) -> MiddlewareType) {
        self.inject = inject
    }
}
