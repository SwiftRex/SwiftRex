/**
 🏄‍ `ActionProtocol` represents an action, usually created by a `Middleware` in response to an event.

 Like events, `ActionProtocol` is also a marker protocol which concrete implementation is a value-type structure holding the associated value that is necessary to request a change in the state. Differently from events, although, actions have more meaningful values and are driven by business logic. While an `EventProtocol` represents taps in the interface and usually has associated values like `3` or `true`, an `ActionProtocol` is expected to hold the information required to mutate the state, such as: "got a new list of movies" with an associated values of `[Movie]`, or "delete invoice" and the associated value being the Invoice object. That way, we should not expect actions to be triggered by an `UIViewController` or SwiftUI `View`, only by a `Middleware` running in the `Store`. Some middlewares can create one or multiple actions out of an event, collecting the proper state information from the indexes passed with the event, and then finally composing a very meaningful action that contains exactly the metadata for the change.

 An event may end up not changing the state, but an action necessarily implies that the state will be mutated accordingly; for example the event `viewDidLoad` may not change your state, having the only purpose of logging or tracking analytics events (let's talk about side-effects later), and in that case don't change anything in the app; while an action `userHasLoggedIn` will necessarily change something on the state.

 ```
 enum MovieListAction: ActionProtocol {
     case setMovieAsWatched(movieId: UUID)
     case setMovieAsUnwatched(movieId: UUID)
     case setCurrentMovieDetailsPage(movie: Movie)
     case setMoviesAsWatched(movies: [Movie])
 }
 ```
 */
public protocol ActionProtocol { }
