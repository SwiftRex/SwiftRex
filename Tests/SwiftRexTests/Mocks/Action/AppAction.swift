import Foundation
import SwiftRex

enum AppAction: Equatable {
    case foo
    case bar(Bar)

    enum Bar: Equatable {
        case alpha
        case bravo
        case charlie
        case delta
        case echo

        var alpha: Void? {
            if case .alpha = self { return () }
            return nil
        }

        var bravo: Void? {
            if case .bravo = self { return () }
            return nil
        }

        var charlie: Void? {
            if case .charlie = self { return () }
            return nil
        }

        var delta: Void? {
            if case .delta = self { return () }
            return nil
        }

        var echo: Void? {
            if case .echo = self { return () }
            return nil
        }
    }

    var foo: Void? {
        if case .foo = self { return () }
        return nil
    }

    var bar: Bar? {
        if case let .bar(bar) = self { return bar }
        return nil
    }
}
