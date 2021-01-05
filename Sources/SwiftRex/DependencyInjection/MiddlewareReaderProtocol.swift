/// A protocol to generalize MiddlewareReader. Unless you look for some very special behaviour, you should use MiddlewareReader directly which
/// provides everything needed for your Middleware dependency injection.
public protocol MiddlewareReaderProtocol {
    /// Dependencies to inject in the middleware. This is equivalent to the parameters in a middleware initializer, usually a tuple with multiple
    /// dependencies separated by comma. In a function `(Dependencies) -> MiddlewareType`, this is at the left-hand side to the arrow.
    associatedtype Dependencies
    /// The resulting middleware after the dependencies are injected.
    /// In a function `(Dependencies) -> MiddlewareType`, this is at the right-hand side to the arrow.
    associatedtype MiddlewareType: Middleware

    /// An initializer function that, given the dependencies in the Middleware's init, will give the Middleware instance
    /// When inject is called, your MiddlewareReader materializes into a Middleware.
    var inject: (Dependencies) -> MiddlewareType { get }

    /// Allows to define a middleware initializer and store this initializer function until we have the dependencies to call it.
    /// This allows us to postpone the dependency injection and compose middlewares that are not even materialized yet.
    /// - Parameter inject: An initializer function that, given the dependencies in the Middleware's init, will give the Middleware instance
    ///                     When inject is called, your MiddlewareReader materializes into a Middleware.
    init(inject: @escaping (Dependencies) -> MiddlewareType)
}
