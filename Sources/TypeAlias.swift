import RxSwift

public typealias GetState<StateType> = () -> StateType
public typealias ReduceFunction<StateType> = (StateType, Action) -> StateType
public typealias EventEvaluation<StateType> = (Event, @escaping GetState<StateType>) -> Observable<Action>
public typealias NextEventHandler<StateType> = (Event, @escaping GetState<StateType>) -> Void
public typealias NextActionHandler<StateType> = (Action, @escaping GetState<StateType>) -> Void
