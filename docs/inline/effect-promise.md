An async task that will start upon subscription and needs to call a completion handler once when it's done.
You can create an Effect promise like this:
```
Effect<String>.promise { completion in
    doSomethingAsync { outputString in
        completion(outputString)
    }
}
```
Internally creates a `Deferred<Future<Output, Never>>`

- Parameters:
  - operation: a closure that gives you a completion handler to be called once the async task is done
- Returns: an `Effect` that will eventually publish the given output when you call the completion handler and that will only call your async task once it's subscribed by the Effect Middleware. Then, it will complete immediately as soon as it emits the first value.