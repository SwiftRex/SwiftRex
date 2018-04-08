import RxSwift

public protocol StateProvider: ObservableType {
    typealias StateType = E
}
