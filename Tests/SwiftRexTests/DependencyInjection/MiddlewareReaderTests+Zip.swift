import SwiftRex
import XCTest

extension MiddlewareReaderTests {
    var middlewares: [MonoidMiddleware<String, String, String>] {
        (0...9)
            .map(String.init)
            .map { MonoidMiddleware<String, String, String>.init(string: $0) }
    }

    var reader: (MonoidMiddleware<String, String, String>) -> MiddlewareReader<String, MonoidMiddleware<String, String, String>> {
        return {
            middleware in
            MiddlewareReader { dependency in
                XCTAssertEqual("some dependency", dependency)
                var m = middleware
                m.string = dependency + " " + middleware.string
                return m
            }
        }
    }

    func testMiddlewareReaderZip2() {
        let sut = MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            with: <>
        )
        XCTAssertEqual("some dependency 0some dependency 1", sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip3() {
        let sut = MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            with: { $0 <> $1 <> $2 }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2", sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip4() {
        let sut = MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            with: { $0 <> $1 <> $2 <> $3 }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3", sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip5() {
        let sut = MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            with: { $0 <> $1 <> $2 <> $3 <> $4 }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4", sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip6() {
        let sut = MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            reader(middlewares[5]),
            with: { $0 <> $1 <> $2 <> $3 <> $4 <> $5 }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4some dependency 5",
                       sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip7() {
        let sut: MiddlewareReader<String, MonoidMiddleware<String, String, String>> =
            MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            reader(middlewares[5]),
            reader(middlewares[6]),
            with: { (
                m0: MonoidMiddleware<String, String, String>,
                m1: MonoidMiddleware<String, String, String>,
                m2: MonoidMiddleware<String, String, String>,
                m3: MonoidMiddleware<String, String, String>,
                m4: MonoidMiddleware<String, String, String>,
                m5: MonoidMiddleware<String, String, String>,
                m6: MonoidMiddleware<String, String, String>
            ) -> MonoidMiddleware<String, String, String> in
                m0 <> m1 <> m2 <> m3 <> m4 <> m5 <> m6
            }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4" +
                       "some dependency 5some dependency 6",
                       sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip8() {
        let sut: MiddlewareReader<String, MonoidMiddleware<String, String, String>> =
            MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            reader(middlewares[5]),
            reader(middlewares[6]),
            reader(middlewares[7]),
            with: { (
                m0: MonoidMiddleware<String, String, String>,
                m1: MonoidMiddleware<String, String, String>,
                m2: MonoidMiddleware<String, String, String>,
                m3: MonoidMiddleware<String, String, String>,
                m4: MonoidMiddleware<String, String, String>,
                m5: MonoidMiddleware<String, String, String>,
                m6: MonoidMiddleware<String, String, String>,
                m7: MonoidMiddleware<String, String, String>
            ) -> MonoidMiddleware<String, String, String> in
                m0 <> m1 <> m2 <> m3 <> m4 <> m5 <> m6 <> m7
            }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4" +
                       "some dependency 5some dependency 6some dependency 7",
                       sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip9() {
        let sut: MiddlewareReader<String, MonoidMiddleware<String, String, String>> =
            MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            reader(middlewares[5]),
            reader(middlewares[6]),
            reader(middlewares[7]),
            reader(middlewares[8]),
            with: { (
                m0: MonoidMiddleware<String, String, String>,
                m1: MonoidMiddleware<String, String, String>,
                m2: MonoidMiddleware<String, String, String>,
                m3: MonoidMiddleware<String, String, String>,
                m4: MonoidMiddleware<String, String, String>,
                m5: MonoidMiddleware<String, String, String>,
                m6: MonoidMiddleware<String, String, String>,
                m7: MonoidMiddleware<String, String, String>,
                m8: MonoidMiddleware<String, String, String>
            ) -> MonoidMiddleware<String, String, String> in
                m0 <> m1 <> m2 <> m3 <> m4 <> m5 <> m6 <> m7 <> m8
            }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4" +
                       "some dependency 5some dependency 6some dependency 7some dependency 8",
                       sut.inject("some dependency").string)
    }

    func testMiddlewareReaderZip10() {
        let sut: MiddlewareReader<String, MonoidMiddleware<String, String, String>> =
            MiddlewareReader<String, MonoidMiddleware<String, String, String>>.zip(
            reader(middlewares[0]),
            reader(middlewares[1]),
            reader(middlewares[2]),
            reader(middlewares[3]),
            reader(middlewares[4]),
            reader(middlewares[5]),
            reader(middlewares[6]),
            reader(middlewares[7]),
            reader(middlewares[8]),
            reader(middlewares[9]),
            with: { (
                m0: MonoidMiddleware<String, String, String>,
                m1: MonoidMiddleware<String, String, String>,
                m2: MonoidMiddleware<String, String, String>,
                m3: MonoidMiddleware<String, String, String>,
                m4: MonoidMiddleware<String, String, String>,
                m5: MonoidMiddleware<String, String, String>,
                m6: MonoidMiddleware<String, String, String>,
                m7: MonoidMiddleware<String, String, String>,
                m8: MonoidMiddleware<String, String, String>,
                m9: MonoidMiddleware<String, String, String>
            ) -> MonoidMiddleware<String, String, String> in
                m0 <> m1 <> m2 <> m3 <> m4 <> m5 <> m6 <> m7 <> m8 <> m9
            }
        )
        XCTAssertEqual("some dependency 0some dependency 1some dependency 2some dependency 3some dependency 4" +
                       "some dependency 5some dependency 6some dependency 7some dependency 8some dependency 9",
                       sut.inject("some dependency").string)
    }
}
