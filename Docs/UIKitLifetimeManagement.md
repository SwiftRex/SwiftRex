# 🌪 UIKit lifetime management

Now imagine that you start an API call to add a movie to your favorites from your details page, but you close that screen before it completes. Having the API Client in your ViewController means that once the screen is dismissed, the completion handler block may not be called, and eventual loggers, trackers or state updates won't happen. That's why we keep API Client and analytics trackers as singletons, independent from UIKit life cycle. As the system grows, we have more and more of these classes making side-effects and all of them is a dependency that must be resolved, or injected, on your ViewController. And that's not enough, if the completion handler of any of these classes need some updated View State to complete other tasks, as analytics trackers for example, you can't simply capture `[unowned self]` or `[weak self]` with `guard let`. Let's illustrate the problem:

```swift
api.fetchNextPage(pageNumber: currentPage + 1,
                  query: searchBar.text) { [weak self] pageResults in
    guard let strongSelf = self else { return }

    strongSelf.currentPage += 1
    strongSelf.dataSource.append(pageResults)

    strongSelf.tracker.trackNextPage(query: strongSelf.searchBar.text,
                                     page: strongSelf.currentPage,
                                     size: pageResults.count,
                                     screenName: strongSelf.screenName,
                                     isUserLoggedIn: strongSelf.userState != nil)
}
```

Now, if the ViewController above is dismissed most of the completion block is not necessary anyway. But still we want to track to our analytics system, and because the `tracker` is part of the ViewController, this will never be called. The solution is to capture `tracker` in the capture block, but not only that, also everything used in the `trackNextPage` call.

```swift
let queryText = searchBar.text
let screenName = self.screenName
let nextPage = currentPage + 1
let isUserLoggedIn = userState != nil

api.fetchNextPage(pageNumber: nextPage,
                  query: searchBar.text) { [weak self, tracker] pageResults in

    tracker.trackNextPage(query: queryText,
                          page: nextPage,
                          size: pageResults.count,
                          screenName: screenName,
                          isUserLoggedIn)

    guard let strongSelf = self else { return }

    strongSelf.currentPage = nextPage
    strongSelf.dataSource.append(pageResults)
}
```

Other solution would be moving the tracker logic to the response of `api.fetchNextPage`, which can violate again some responsibilities and demand you to call this method with more parameters than it should need, just to satisfy other side-effects there, the tracking.