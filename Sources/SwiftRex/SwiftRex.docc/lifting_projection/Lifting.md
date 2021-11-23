# Lifting

An app can be a complex product, performing several activities that not necessarily are related. For example, the same app may need to perform a request to a weather API, check the current user location using CLLocation and read preferences from UserDefaults.

Although these activities are combined to create the full experience, they can be isolated from each other in order to avoid URLSession logic and CLLocation logic in the same place, competing for the same resources and potentially causing race conditions. Also, testing these parts in isolation is often easier and leads to more significant tests. 

Ideally we should organise our `AppState` and `AppAction` to account for these parts as isolated trees. In the example above, we could have 3 different properties in our AppState and 3 different enum cases in our AppAction to group state and actions related to the weather API, to the user location and to the UserDefaults access.

This gets even more helpful in case we split our app in 3 types of ``Reducer`` and 3 types of ``MiddlewareProtocol``, and each of them work not on the full `AppState` and `AppAction`, but in the 3 paths we grouped in our model. The first pair of ``Reducer`` and ``MiddlewareProtocol`` would be generic over ``WeatherState`` and ``WeatherAction``, the second pair over ``LocationState`` and ``LocationAction`` and the third pair over ``RepositoryState`` and ``RepositoryAction``. They could even be in different frameworks, so the compiler will forbid us from coupling Weather API code with CLLocation code, which is great as this enforces better practices and unlocks code reusability. Maybe our CLLocation middleware/reducer can be useful in a completely different app that checks for public transport routes.

But at some point we want to put these 3 different types of entities together, and the ``StoreType`` of our app "speaks" `AppAction` and `AppState`, not the subsets used by the specialised handlers.

```swift
enum AppAction {
    case weather(WeatherAction)
    case location(LocationAction)
    case repository(RepositoryAction)
}
struct AppState {
    let weather: WeatherState
    let location: LocationState
    let repository: RepositoryState
}
```
Given a reducer that is generic over `WeatherAction` and `WeatherState`, we can "lift" it to the global types `AppAction` and `AppState` by telling this reducer how to find in the global tree the properties that it needs. That would be `\AppAction.weather` and `\AppState.weather`. The same can be done for the middleware, and for the other 2 reducers and middlewares of our app.

When all of them are lifted to a common type, they can be combined together using the diamond operator (`<>`) and set as the store handler.

> **_IMPORTANT:_** Because enums in Swift don't have KeyPath as structs do, we strongly recommend reading [Action Enum Properties](docs/markdown/ActionEnumProperties.md) document and implementing properties for each case, either manually or using code generators, so later you avoid writing lots and lots of error-prone switch/case. We also offer some templates to help you on that.

Let's explore how to lift reducers and middlewares. 

## Lifting Reducer

``Reducer`` has AppAction INPUT, AppState INPUT and AppState OUTPUT, because it can only handle actions (never dispatch them), read the state and write the state.

The lifting direction, therefore, should be:
```
Reducer:
- ReducerAction? ← AppAction
- ReducerState ←→ AppState
```

Given:
```swift
//      type 1         type 2
Reducer<ReducerAction, ReducerState>
```

Transformations:
```
                                                                                 ╔═══════════════════╗
                                                                                 ║                   ║
                       ╔═══════════════╗                                         ║                   ║
                       ║    Reducer    ║ .lift                                   ║       Store       ║
                       ╚═══════════════╝                                         ║                   ║
                               │                                                 ║                   ║
                                                                                 ╚═══════════════════╝
                               │                                                           │          
                                                                                                      
                               │                                                           │          
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppAction) -> ReducerAction?               │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │  Reducer  │   { $0.case?.reducerAction }                  │           │    
    Input Action         │  Action   │◀──────────────────────────────────────────────│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   KeyPath<AppAction, ReducerAction?>          │           │    
                         └─────┬─────┘   \AppAction.case?.reducerAction              │           │    
                                                                                     └───────────┘    
                               │                                                           │          
                                                                                                      
                               │         get: (AppState) -> ReducerState                   │          
                                         { $0.reducerState }                         ┌───────────┐    
                         ┌─────┴─────┐   set: (inout AppState, ReducerState) -> Void │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │  Reducer  │   { $0.reducerState = $1 }                    │           │    
        State            │   State   │◀─────────────────────────────────────────────▶│ AppState  │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   WritableKeyPath<AppState, ReducerState>     │           │    
                         └─────┬─────┘   \AppState.reducerState                      │           │    
                                                                                     └───────────┘    
                               │                                                           │          
```

### Lifting Reducer using closures:
```swift
.lift(
    actionGetter: { (action: AppAction) -> ReducerAction? /* type 1 */ in 
        // prism3 has associated value of ReducerAction,
        // and whole thing is Optional because Prism is always optional
        action.prism1?.prism2?.prism3
    },
    stateGetter: { (state: AppState) -> ReducerState /* type 2 */ in 
        // property2: ReducerState
        state.property1.property2
    },
    stateSetter: { (state: inout AppState, newValue: ReducerState /* type 2 */) -> Void in 
        // property2: ReducerState
        state.property1.property2 = newValue
    }
)
```
Steps:
- Start plugging the 2 types from the Reducer into the 3 closure headers.
- For type 1, find a prism that resolves from AppAction into the matching type. **BE SURE TO RUN SOURCERY AND HAVING ALL ENUM CASES COVERED BY PRISM**
- For type 2 on the stateGetter closure, find lenses (property getters) that resolve from AppState into the matching type.
- For type 2 on the stateSetter closure, find lenses (property setters) that can change the global state receive to the newValue received. Be sure that everything is writeable.

### Lifting Reducer using KeyPath:
```swift
.lift(
    action: \AppAction.prism1?.prism2?.prism3,
    state: \AppState.property1.property2
)
```
Steps:
- Start with the closure example above
- For action, we can use KeyPath from `\AppAction` traversing the prism tree
- For state, we can use WritableKeyPath from `\AppState` traversing the properties as long as all of them are declared as `var`, not `let`.

## Lifting Middleware

``MiddlewareProtocol`` has AppAction INPUT, AppAction OUTPUT and AppState INPUT, because it can handle actions, dispatch actions, and only read the state (never write it).

The lifting direction, therefore, should be:
```
Middleware:
- MiddlewareInputAction? ← AppAction
- MiddlewareOutputAction → AppAction
- MiddlewareState ← AppState
```

Given:
```swift
//           type 1                 type 2                  type 3
MyMiddleware<MiddlewareInputAction, MiddlewareOutputAction, MiddlewareState>
```

Transformations:
```
                                                                                 ╔═══════════════════╗
                                                                                 ║                   ║
                       ╔═══════════════╗                                         ║                   ║
                       ║  Middleware   ║ .lift                                   ║       Store       ║
                       ╚═══════════════╝                                         ║                   ║
                               │                                                 ║                   ║
                                                                                 ╚═══════════════════╝
                               │                                                           │          
                                                                                                      
                               │                                                           │          
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppAction) -> MiddlewareInputAction?       │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   { $0.case?.middlewareInputAction }          │           │    
    Input Action         │   Input   │◀──────────────────────────────────────────────│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │  Action   │   KeyPath<AppAction, MiddlewareInputAction?>  │           │    
                         └─────┬─────┘   \AppAction.case?.middlewareInputAction      │           │    
                                                                                     └───────────┘    
                               │                                                     ┌─────┴─────┐    
                         ┌───────────┐   (MiddlewareOutputAction) -> AppAction       │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   { AppAction.case($0) }                      │           │    
    Output Action        │  Output   │──────────────────────────────────────────────▶│ AppAction │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │  Action   │   AppAction.case                              │           │    
                         └───────────┘                                               │           │    
                               │                                                     └─────┬─────┘    
                                                                                     ┌───────────┐    
                         ┌─────┴─────┐   (AppState) -> MiddlewareState               │           │    
┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │Middleware │   { $0.middlewareState }                      │           │    
        State            │   State   │◀──────────────────────────────────────────────│ AppState  │    
└ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │           │   KeyPath<AppState, MiddlewareState>          │           │    
                         └─────┬─────┘   \AppState.middlewareState                   │           │    
                                                                                     └───────────┘    
                               │                                                           │          
```

### Lifting Middleware using closures:
```swift
.lift(
    inputAction: { (action: AppAction) -> MiddlewareInputAction? /* type 1 */ in
        // prism3 has associated value of MiddlewareInputAction,
        // and whole thing is Optional because Prism is always optional
        action.prism1?.prism2?.prism3
    },
    outputAction: { (local: MiddlewareOutputAction /* type 2 */) -> AppAction in
        // local is MiddlewareOutputAction, 
        // an associated value for .prism3
        AppAction.prism1(.prism2(.prism3(local)))
    },
    state: { (state: AppState) -> MiddlewareState /* type 3 */ in
        // property2: MiddlewareState
        state.property1.property2
    }
)
```
Steps:
- Start plugging the 3 types from MyMiddleware into the closure headers.
- For type 1, find a prism that resolves from AppAction into the matching type. **BE SURE TO RUN SOURCERY AND HAVING ALL ENUM CASES COVERED BY PRISM**
- For type 2, wrap it from inside to outside until you reach AppAction, in this example we wrap it (being "it" = local) in .prism3, which we wrap in .prism2, then .prism1 to finally reach AppAction.
- For type 3, find lenses (property getters) that resolve from AppState into the matching type.

### Lifting Middleware using KeyPath:
```swift
.lift(
    inputAction: \AppAction.prism1?.prism2?.prism3,
    outputAction: Prism2.prism3,
    state: \AppState.property1.property2
)
.lift(outputAction: Prism1.prism2)
.lift(outputAction: AppAction.prism1)
```
Steps:
- Start with the closure example above
- For inputAction, we can use KeyPath from `\AppAction` traversing the prism tree
- For outputAction it's **NOT** a KeyPath, but a wrapping. Because we can't wrap more than 1 level at once, either we:
    - use the closure version for this one
    - lift level by level, from inside to outside, in that case follow the steps of wrapping local into Prism2 (case .prism3), then wrapping result into Prism1 (case .prism2), then wrapping result into AppAction (case .prism1)
- When it's only 1 level, there's nothing to worry about
- For state, we can use KeyPath from `\AppState` traversing the properties.

## Optional transformation
If some action is running through the store, some reducers and middlewares may opt for ignoring it. For example, if the action tree has nothing to do with that middleware or reducer. That's why, every INCOMING action (InputAction for Middlewares and simply Action for Reducers) is a transformation from `AppAction → Optional<Subset>`. Returning nil means that the action will be ignored.

This is not true for the other direction, when actions are dispatched by Middlewares, they MUST become an AppAction, we can't ignore what Middlewares have to say.

## Direction of the arrows
**Reducers** receive actions (input action) and are able to read and write state.

**Middlewares** receive actions (input action), dispatch actions (output action) and only read the state (input state).

When lifting, we must keep that in mind because it defines the variance (covariant/contravariant) of the transformation, that is, _map_ or _contramap_.

One special case is the State for reducer, because that requires a read and write access, in other words, you are given an `inout Whole` and a new value for `Part`, you use that new value to set the correct path inside the inout Whole. This is precisely what WritableKeyPaths are mean for, which we will see with more details now.

## Use of KeyPaths
KeyPath is the same as `Global -> Part` transformation, where you give the description of the tree in the following way:
`\Global.parent.part`.

WritableKeyPath has similar usage syntax, but it's much more powerful, allowing us to transform `(Global, Part) -> Global`, or `(inout Global, Part) -> Void` which is the same.

That said we need to understand that KeyPaths are only possible when the direction of the arrows comes from `AppElement -> ReducerOrMiddlewareElement`, that is:
```
Reducer:
- ReducerAction? ← AppAction         // Keypath is possible
- ReducerState ←→ AppState           // WritableKeyPath is possible
```
```
Middleware:
- MiddlewareInputAction? ← AppAction // KeyPath is possible
- MiddlewareOutputAction → AppAction // NOT POSSIBLE
- MiddlewareState ← AppState         // KeyPath is possible
```

For the `ReducerAction? ← AppAction` and `MiddlewareInputAction? ← AppAction` we can use KeyPaths that resolve to `Optional<ReducerOrMiddlewareAction>`:
```swift
{ (globalAction: AppAction) -> ReducerOrMiddlewareAction? in
    globalAction.parent?.reducerOrMiddlewareAction
}

// or
// KeyPath<AppAction, ReducerOrMiddlewareAction?>
\AppAction.parent?.reducerOrMiddlewareAction
```

For the `ReducerState ←→ AppState` and `MiddlewareState ← AppState` transformations, we can use similar syntax although the Reducer is inout (WritableKeyPath). That means our whole tree must be composed by `var` properties, not `let`. In this case, unless the Middleware or Reducer accepts Optional, the transformation should NOT be Optional.
```swift
{ (globalState: AppState) -> PartState in
    globalState.something.thatsThePieceWeWant
}

{ (globalState: inout AppState, newValue: PartState) -> Void in
    globalState.something.thatsThePieceWeWant = newValue
}

// or
// KeyPath<AppState, PartState> or WritableKeyPath<AppState, PartState>
\AppState.something.thatsThePieceWeWant // where:
                                        // var something
                                        // var thatsThePieceWeWant
```

For the `MiddlewareOutputAction → AppAction` we can't use keypath, it doesn't make sense, because the direction is the opposite of what we want. In that case we are not unwrapping/extracting the part from a global value, we were given a specific action from certain middleware and we need to wrap it into the AppAction. This can be achieved by two forms:
```swift
{ (middlewareAction: MiddlewareAction) -> AppAction in 
    AppAction.treeForMiddlewareAction(middlewareAction)
}

// or simply

AppAction.treeForMiddlewareAction // please notice, not KeyPath, it doesn't start by \
```

The short form, however, can't traverse 2 levels at once:
```swift
{ (middlewareAction: MiddlewareAction) -> AppAction in 
    AppAction.firstLevel( FirstLevel.secondLevel(middlewareAction) )
}

// this will NOT compile (although a better Prism could solve that, probably):
AppAction.firstLevel.secondLevel

// You could try, however, to lift twice:
.lift(outputAction: FirstLevel.secondLevel) // Notice that first we wrap the middleware value in the second level
.lift(outputAction: AppAction.firstLevel)   // And then we wrap the first level in the AppAction
                                            // The order must be from inside to outside, always.
```

## Identity, Ignore and Absurd
Void:
- when Middleware doesn't need State, it can be Void
- lift Void using `ignore`, which is `{ (_: Anything) -> Void in }`

Never:
- when Middleware doesn't need to dispatch actions, it can be Never
- lift Never using `absurd`, which is `{ (never: Never) -> Anything in }`

Identity:
- when some parts of your lift should be unchanged because they are already in the expected type
- lift that using `identity`, which is `{ $0 }`

Theory behind:
Void and Never are dual:
- Anything can become Void (terminal object)
- Never (initial object) can become Anything
- Void has 1 instance possible (it's a singleton)
- Never has 0 instances possible
- Because nobody can give you Never, you can promise Anything as a challenge. That's why function is called absurd, it's impossible to call it.

## Xcode Snippets:
```swift
// Reducer expanded
.lift(
    actionGetter: { (action: AppAction) -> <#LocalAction#>? in action.<#something?.child#> },
    stateGetter: { (state: AppState) -> <#LocalState#> in state.<#something.child#> },
    stateSetter: { (state: inout AppState, newValue: <#LocalState#>) -> Void in state.<#something.child#> = newValue }
)

// Reducer KeyPath:
.lift(
    action: \AppAction.<#something?.child#>,
    state: \AppState.<#something.child#>
)

// Middleware expanded
.lift(
    inputAction: { (action: AppAction) -> <#LocalAction#>? in action.<#something?.child#> },
    outputAction: { (local: <#LocalAction#>) -> AppAction in AppAction.<#something(.child(local))#> },
    state: { (state: AppState) -> <#LocalState#> in state.<#something.child#> }
)

// Middleware KeyPath
.lift(
    inputAction: \AppAction.<#local#>,
    outputAction: AppAction.<#local#>, // not more than 1 level
    state: \AppState.<#local#>
)
```
