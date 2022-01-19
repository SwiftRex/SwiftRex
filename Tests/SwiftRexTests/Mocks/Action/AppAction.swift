import Foundation
import SwiftRex

enum AppAction: Equatable {
    case foo
    case bar(Bar)
    case scoped(ElementIDAction<Int, Bar>)

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

    var scoped: ElementIDAction<Int, Bar>? {
        get {
            if case let .scoped(action) = self { return action }
            return nil
        }
        set {
            guard case .scoped = self, let newValue = newValue else { return }
            self = .scoped(newValue)
        }
    }
}

enum ActionForScopedTests {
    case toIgnore
    case somethingScopedById(ElementIDAction<Int, String>)
    case somethingScopedByIndex(ElementIndexAction<Int, String>)

    var toIgnore: Void? {
        if case .toIgnore = self { return () }
        return nil
    }

    var somethingScopedById: ElementIDAction<Int, String>? {
        if case let .somethingScopedById(action) = self { return action }
        return nil
    }

    var somethingScopedByIndex: ElementIndexAction<Int, String>? {
        if case let .somethingScopedByIndex(action) = self { return action }
        return nil
    }
}
