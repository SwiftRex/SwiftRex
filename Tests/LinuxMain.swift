import XCTest

import ReactiveSwiftRexTests
import RxSwiftRexTests
import SwiftRexTests

var tests = [XCTestCaseEntry]()
tests += ReactiveSwiftRexTests.__allTests()
tests += RxSwiftRexTests.__allTests()
tests += SwiftRexTests.__allTests()

XCTMain(tests)
