import Foundation

extension MiddlewareReaderProtocol {
    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<M1: MiddlewareReaderProtocol, M2: MiddlewareReaderProtocol, MOutput: Middleware>(
        _ reader1: M1,
        _ reader2: M2,
        with map: @escaping (M1.MiddlewareType, M2.MiddlewareType) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput> where M1.Dependencies == M2.Dependencies {
        MiddlewareReader { environment in
            map(reader1.inject(environment), reader2.inject(environment))
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<M1: MiddlewareReaderProtocol, M2: MiddlewareReaderProtocol, M3: MiddlewareReaderProtocol, MOutput: Middleware>(
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        with map: @escaping (M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput> where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies {
        MiddlewareReader { environment in
            map(reader1.inject(environment), reader2.inject(environment), reader3.inject(environment))
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        with map: @escaping (M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies {
        MiddlewareReader { environment in
            map(reader1.inject(environment), reader2.inject(environment), reader3.inject(environment), reader4.inject(environment))
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        with map: @escaping (M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment)
            )
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - reader6: sixth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        M6: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        _ reader6: M6,
        with map: @escaping (
            M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType, M6.MiddlewareType
        ) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies, M1.Dependencies == M6.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment),
                reader6.inject(environment)
            )
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - reader6: sixth reader type
    ///   - reader7: seventh reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        M6: MiddlewareReaderProtocol,
        M7: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        _ reader6: M6,
        _ reader7: M7,
        with map: @escaping (
            M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType, M6.MiddlewareType, M7.MiddlewareType
        ) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies, M1.Dependencies == M6.Dependencies, M1.Dependencies == M7.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment),
                reader6.inject(environment),
                reader7.inject(environment)
            )
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - reader6: sixth reader type
    ///   - reader7: seventh reader type
    ///   - reader8: eighth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        M6: MiddlewareReaderProtocol,
        M7: MiddlewareReaderProtocol,
        M8: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        _ reader6: M6,
        _ reader7: M7,
        _ reader8: M8,
        with map: @escaping (
            M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType, M6.MiddlewareType, M7.MiddlewareType,
            M8.MiddlewareType
        ) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies, M1.Dependencies == M6.Dependencies, M1.Dependencies == M7.Dependencies,
          M1.Dependencies == M8.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment),
                reader6.inject(environment),
                reader7.inject(environment),
                reader8.inject(environment)
            )
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - reader6: sixth reader type
    ///   - reader7: seventh reader type
    ///   - reader8: eighth reader type
    ///   - reader9: ninth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        M6: MiddlewareReaderProtocol,
        M7: MiddlewareReaderProtocol,
        M8: MiddlewareReaderProtocol,
        M9: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        _ reader6: M6,
        _ reader7: M7,
        _ reader8: M8,
        _ reader9: M9,
        with map: @escaping (
            M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType, M6.MiddlewareType, M7.MiddlewareType,
            M8.MiddlewareType, M9.MiddlewareType
        ) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies, M1.Dependencies == M6.Dependencies, M1.Dependencies == M7.Dependencies,
          M1.Dependencies == M8.Dependencies, M1.Dependencies == M9.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment),
                reader6.inject(environment),
                reader7.inject(environment),
                reader8.inject(environment),
                reader9.inject(environment)
            )
        }
    }

    /// Creates a MiddlewareReader that combines multiple readers into one, as long as they depend on same environment. Once this environment is
    /// injected, upstream readers will run and the result will be a tuple containing the resulting values of each upstream reader. Then you provide
    /// a way to combine there resulting Middlewares into one.
    ///
    /// - Parameters:
    ///   - reader1: first reader type
    ///   - reader2: second reader type
    ///   - reader3: third reader type
    ///   - reader4: fourth reader type
    ///   - reader5: fifth reader type
    ///   - reader6: sixth reader type
    ///   - reader7: seventh reader type
    ///   - reader8: eighth reader type
    ///   - reader9: ninth reader type
    ///   - reader10: tenth reader type
    ///   - map: how to combine produced middlewares into a single one, of type `MOutput`
    /// - Returns: middleware reader that gives a middleware of type `MOutput` after receiving the injected dependencies
    public static func zip<
        M1: MiddlewareReaderProtocol,
        M2: MiddlewareReaderProtocol,
        M3: MiddlewareReaderProtocol,
        M4: MiddlewareReaderProtocol,
        M5: MiddlewareReaderProtocol,
        M6: MiddlewareReaderProtocol,
        M7: MiddlewareReaderProtocol,
        M8: MiddlewareReaderProtocol,
        M9: MiddlewareReaderProtocol,
        M10: MiddlewareReaderProtocol,
        MOutput: Middleware
    > (
        _ reader1: M1,
        _ reader2: M2,
        _ reader3: M3,
        _ reader4: M4,
        _ reader5: M5,
        _ reader6: M6,
        _ reader7: M7,
        _ reader8: M8,
        _ reader9: M9,
        _ reader10: M10,
        with map: @escaping (
            M1.MiddlewareType, M2.MiddlewareType, M3.MiddlewareType, M4.MiddlewareType, M5.MiddlewareType, M6.MiddlewareType, M7.MiddlewareType,
            M8.MiddlewareType, M9.MiddlewareType, M10.MiddlewareType
        ) -> MOutput
    ) -> MiddlewareReader<M1.Dependencies, MOutput>
    where M1.Dependencies == M2.Dependencies, M1.Dependencies == M3.Dependencies, M1.Dependencies == M4.Dependencies,
          M1.Dependencies == M5.Dependencies, M1.Dependencies == M6.Dependencies, M1.Dependencies == M7.Dependencies,
          M1.Dependencies == M8.Dependencies, M1.Dependencies == M9.Dependencies, M1.Dependencies == M10.Dependencies {
        MiddlewareReader { environment in
            map(
                reader1.inject(environment),
                reader2.inject(environment),
                reader3.inject(environment),
                reader4.inject(environment),
                reader5.inject(environment),
                reader6.inject(environment),
                reader7.inject(environment),
                reader8.inject(environment),
                reader9.inject(environment),
                reader10.inject(environment)
            )
        }
    }
}
