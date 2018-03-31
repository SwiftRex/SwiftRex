public protocol StateProvider {
    associatedtype StateType
    func subscribe() -> Observable<StateType>
}
