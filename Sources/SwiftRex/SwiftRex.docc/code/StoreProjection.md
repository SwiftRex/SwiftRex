# ``SwiftRex/StoreProjection``

Very often you don't want your view to be able to access the whole App State or dispatch any possible global App Action. Not only it could refresh
your UI more often than needed, it also makes more error prone, put more complex code in the view layer and finally decreases modularisation making
the view coupled to the global models.

However, you don't want to split your state in multiple parts because having it in a central and unique point ensures consistency. Also, you don't
want multiple separate places taking care of actions because that could potentially create race conditions. The real Store is the only place actually
owning the global state and effectively handling the actions, and that's how it's supposed to be.

To solve both problems, we offer a ``StoreProjection``, which conforms to the ``StoreType`` protocol so for all purposes it behaves like a real store,
but in fact it only projects the real store using custom types for state and actions, that is, either a subset of your models (a branch in the state
tree, for example), or a completely different entity like a View State. A ``StoreProjection`` has 2 closures, that allow it to transform actions and
state between the global ones and the ones used by the view. That way, the View is not coupled to the whole global models, but only to tiny parts of
it, and the closure in the ``StoreProjection`` will take care of extracting/mapping the interesting part for the view. This also improves performance,
because the view will not refresh for any property in the global state, only for the relevant ones. On the other direction, view can only dispatch a
limited set of actions, that will be mapped into global actions by the closure in the ``StoreProjection``.

A Store Projection can be created from any other ``StoreType``, even from another ``StoreProjection``. It's as simple as calling 
``StoreType/projection(action:state:)``, and providing the action and state mapping closures:

```swift
let storeProjection = store.projection(
    action: { viewAction in viewAction.toAppAction() } ,
    state: { globalState in MyViewState.from(globalState: globalState) }
).asObservableViewModel(initialState: .empty)
```

For more information about real store vs. store projections, and also for complete code examples, please check documentation for ``StoreType``.
