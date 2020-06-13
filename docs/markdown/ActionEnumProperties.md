# Action Enum Properties

Because enums in Swift don't have KeyPath as structs, we strongly recommend you to create enum properties for every case, so you can easily traverse enum trees as well as reading associated values. There are several ways to create enum properties, either manually or using code generation tools.

Having Action enum properties will be very beneficial when lifting actions, specially when extracting a possible local action out of an AppAction for example:

```swift
// Instead of
.lift(action: { (globalAction: AppAction) -> LocalAction? in 
    if case let .localActionEnumCase(localAction) = globalAction { return localAction }
    return nil
})

// You can do
.lift(action: { $0.localActionEnumCase })

// Or even
.lift(action: \.localActionEnumCase)
```

So the shape `(AppAction) -> LocalAction?` can be used as a simple `\AppAction.enumProperty` KeyPath, usually inferred to `\.enumProperty`. It's not only a matter of syntax sugar, it's a way to avoid opening closures that can contain bugs, typos, mistakes.
KeyPaths are compile-checked, and if you use code-generation for creating the enum properties, you reduce enormously the error possibility.

Please notice that these key-paths always return Optional, that's because enum cases are mutually exclusive, and when extracting a local from a global, we return nil whenever the current instance has a different case. If you want to learn more about the Mathematics behind this, please look for `Functional Programming Optics: Prism` on your favourite search engine. :)

---

## Manually

An enum property will always return the Optional value of the case's associated value (or Optional<Void> for cases without associated values), and setter will do the opposite. For example.

```swift
enum AppAction {
    case started
    case movie(MovieAction)
    case sayHello(String, String)
}

// Boilerplate enum property
extension AppAction {
    public var started: Void? {
        guard case .started = self else { return nil }
        return ()
    }

    var movie: MovieAction? {
        get {
            guard case let .movie(value) = self else { return nil }
            return value
        }
        set {
            guard case .movie = self, let newValue = newValue else { return }
            self = .movie(newValue)
        }
    }

    var sayHello: (String, String)? {
        get {
            guard case let .sayHello(value1, value2) = self else { return nil }
            return (value1, value2)
        }
        set {
            guard case .sayHello = self, let (value1, value2) = newValue else { return }
            self = .sayHello(value1, value2)
        }
    }
}
```

As you can see, "started" case doesn't have associated values, so no need for setter and also the getter will be of type `Void?`, which means `Void` in case that instance is `AppAction.started` or `nil` in case it's anything else. When the enum case has associated values, one or many, this should be returned as result for the getter (a single type or a tuple), or `nil` if the instance has a different case.

---

## Xcode Code Snippets

You can do that manually or using Xcode Code Snippets, as the ones below.

Xcode Code Snippet for cases with associated values (it can be downloaded from [here](CodeSnippet/PrismAssociatedValue.codesnippet) and saved into ~/Library/Developer/Xcode/UserData/CodeSnippets):

```swift
extension <#ActionName#> {
    public var <#actionCase#>: <#AssociatedValueTypeOrTuple#>? {
        get {
            guard case let .<#actionCase#>(value) = self else { return nil }
            return value
        }
        set {
            guard case .<#actionCase#> = self, let newValue = newValue else { return }
            self = .<#actionCase#>(newValue)
        }
    }
}
```

Xcode Code Snippet for cases with no associated value (it can be downloaded from [here](CodeSnippet/PrismVoid.codesnippet) and saved into ~/Library/Developer/Xcode/UserData/CodeSnippets):

```swift
extension <#ActionName#> {
    public var <#actionCase#>: Void? {
        guard case .<#actionCase#> = self else { return nil }
        return ()
    }
}
```

---

## Sourcery

Another option is using [Sourcery](https://github.com/krzysztofzablocki/Sourcery), [the template is available here](SourceryTemplates/Prism.stencil). You can run Sourcery using this template by simply annotating your enums with `// sourcery: Prism` comment, as seen below:

```swift
// sourcery: Prism
enum AppAction {
    case started
    case movie(MovieAction)
    case sayHello(String, String)
}
```

Sourcery will then create the file `Prism.generated.swift` that must be added to your project. You can easily add this as a build step to Xcode so the enum properties will get refreshed every time you add a new case or a new sub-Action.

This is the way we recommend and a full example can be seen on [SwiftMonitor project](https://github.com/SwiftRex/SwiftRexMonitor/tree/master/SwiftRexMonitor).

---

## Other options

[Enum Properties](https://github.com/pointfreeco/swift-enum-properties) project is a code generator solution only for Enum Properties problem, but it creates the extensions inline side-by-side with the enum itself, disturbing the development process. Because Sourcery is more powerful, can be used for more situations, and creates an external file, we would recommend using that instead.

A last option is using [Case Paths library](https://github.com/pointfreeco/swift-case-paths), which creates an enum KeyPath syntax for any enum automatically. Although the easiest one and compatible with SwiftRex, we don't recommend that solution for relying on Reflection/Introspection techniques, that could come with some performance implications. Code generated solution will always be the most optimizes way as you transfer the processing time from app runtime to build times.