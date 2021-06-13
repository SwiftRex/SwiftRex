/*:
 # Simple Counter

 In this playground we're going to create a simple app that allows you to
 count things. It will have a text field showing the current count, as well
 as an "increment" and "decrement" button. This explanation assumes
 that you already know the redux design pattern and terminilogy. If you
 need more information on that, the [Redux for JavaScript web site](https://redux.js.org/basics/data-flow) is a good
 source of information.

 ## Requirements

 In order for this playground to work, you must:
 * open the `Playgrounds.xcworkspace` file (**not** the `Playgrounds.xcodeproj` file!)
 * select an ios simulator as the build target
 * build the `SwiftRex-Package` target

 After that, the playground should work.

 Let's get started.

 ## State

 Our data model is about as simple as it gets: an integer that holds
 the current count. So let's define our `State`.
 */

struct AppState: Equatable {
    var count: Int
}

let initialAppState = AppState(count: 0)

/*:
 Please note that the state needs to conform to Equatable. Most
 of the time all that is needed for that is declaring the protocol
 conformance, the Swift compiler will synthesize the appropriate
 logic for you.

 ## Action Type

 Before we can define our app reduer, we first need to have a
 type that represents our actions. SwiftRex doesn't provide anything
 special for that, you can simply define your own. Let's define an empty
 enum, we'll add actions later.
 */

enum AppAction {
    case testAction
}

/*:
 ## Reducer

 Next we need a reducer, which transforms a state to the next
 state based on the action that it is passed. We'll start with an
 empty reducer and fill out the details later.
 */

//func appReducer(action: AppAction, _ state: AppState) -> AppState {
//    return state
//}



import SwiftRex
import CombineRex

let appReducer = Reducer<AppAction, AppState>({action, state in
    var newState = state
    newState.count += 1
    return newState
})

/*:
 ## Store

 That gives us all the building blocks we need to be able to
 define our store. We'll use the provided `ReduxStoreBase`
 as a starting point.
 */

class AppStore: ReduxStoreBase<AppAction, AppState> {
    init() {
        super.init(
            subject: .combine(initialValue: initialAppState),
            reducer: appReducer,
            middleware: IdentityMiddleware(),
            emitsValue: .whenDifferent
        )
    }
}

let store = AppStore()
store.statePublisher.subscribe(SubscriberType<AppState, Never>(onValue: { (state) in
    print(state)
}, onCompleted: { _ in
    print("completed")
}, onSubscribe: { (subscriptionType) in
    print("subscribed \(subscriptionType)")
})
)

store.dispatch(.testAction)

