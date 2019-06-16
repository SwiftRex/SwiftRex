//#if canImport(RxSwift)
//import RxSwift
//
//extension StoreBase {
//    public typealias Element = State
//
//    /**
//     Because `StoreBase` is a `StateProvider`, it exposes a way for an `UIViewController` or other interested classes to subscribe to `State` changes.
//
//     By default, this observation will have the following characteristics:
//     - Hot observable, no observation side-effect
//     - Replays the last (or initial) state
//     - Never completes
//     - Never fails
//     - Observes on the `MainScheduler`
//
//     Internally it maps to a `BehaviorSubject<StateType>`.
//
//     - Parameter observer: the action to be managed by this store and handled by its middlewares and reducers
//     - Returns: Subscription for `observer` that should be kept in a `disposeBag` for the same lifetime as its observer.
//     */
//    public func subscribe<O>(_ observer: O) -> Disposable where O: ObserverType, O.Element == StateType {
//        return state
//            .observeOn(MainScheduler.instance)
//            .subscribe(observer)
//    }
//}
//#endif
