# 🚦 State management

Let's first define "state". State is anything that can mutate during the lifetime of an application. That means we have different kinds of state, such as:
- View State that holds values of View properties as the user scrolls the screen or selects rows
- Model State holding all the movies you've fetched from the database
- Navigation State is also an important piece that represents where the user has been and how did they get there.

As a system grows, some of these pieces may start to get shared by multiple parts. Imagine, for example, a split-view showing on the right side the details of a movie and on the left side the list of all movies, and as you mark one as favorite, both screens should be updated at the same time. Things get more complicated once you have analytics trackers, loggers, API calls to mutate data with completion handlers that could tell you about an error on your request or a success. Everything should keep consistently in sync, but at the same time it's much easier to have a boolean variable `isFavorite` on the table view cell on the left and another `isFavorite` boolean on your movie details page. Everything trying to update from your API response consistently.

Let's see how's the suggested approach from Apple to deal with the MVC layers:

![iOS MVC](https://luizmb.github.io/SwiftRex/markdown/img/CocoaMVC.gif)

According to this diagram, the Model should be updated and notify the controllers about the new state. If we share this Model with two controllers, the model should notify both, right? So in that case neither Delegation pattern or Completion Handler would work, as they are not meant to be multicast notifiers. Possible solutions are `NotificationCenter` or KVO, the first has no type-safety and the second has no consistency across frameworks. `RxSwift` brings us `Observable` structures that allow multiple observers to be notified in a consistent and type-safe way. Moreover, `Observables` are very flexible, allowing us to compose transformations and filters, to combine multiple `Observable` sources into one, to throttle, debounce and buffer multiple results and much more.
