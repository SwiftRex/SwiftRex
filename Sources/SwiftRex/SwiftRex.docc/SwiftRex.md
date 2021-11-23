# ``SwiftRex``

Unidirectional Dataflow for your favourite reactive framework.

## Overview

SwiftRex is a framework that combines Unidirectional Dataflow architecture and reactive programming ([Combine](https://developer.apple.com/documentation/combine), [RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveSwift](https://github.com/ReactiveCocoa/ReactiveSwift)), providing a central state Store for the whole state of your app, of which your SwiftUI Views or UIViewControllers can observe and react to, as well as dispatching events coming from the user interactions.

This pattern, also known as ["Redux"](https://redux.js.org/basics/data-flow), allows us to rethink our app as a single [pure function](https://en.wikipedia.org/wiki/Pure_function) that receives user events as input and returns UI changes in response. The benefits of this workflow will hopefully become clear soon.

If you've got questions, about SwiftRex or redux and Functional Programming in general, please [Join our Slack Channel](https://join.slack.com/t/swiftrex/shared_invite/zt-oko9h1z4-Nq4YsK2FbMJ~giN01sdDeQ).

## Topics

### Discussions
- <doc:Goals>
- <doc:ReactiveFrameworks>
- <doc:Installation>

### Learning
- <doc:QuickGuide>
- <doc:GettingStarted>
- <doc:Action>
- <doc:State>
- ``StoreType``
- ``MiddlewareProtocol``
- ``Middleware``
- ``Reducer``

### Projection and Lifting
- <doc:Lifting>
- ``SwiftRex/StoreProjection``

### Middlewares
- ``AnyMiddleware``
- ``ComposedMiddleware``
- ``IdentityMiddleware``
- ``MiddlewareReader``
- ``MiddlewareReaderProtocol``

### Stores
- ``ReduxStoreBase``
- ``ReduxStoreProtocol``
- ``AnyStoreType``

### Advanced
- <doc:Architecture>
