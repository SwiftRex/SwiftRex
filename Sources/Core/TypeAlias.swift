import RxSwift

public typealias GetState<StateType> = () -> StateType
public typealias ReduceFunction<StateType> = (StateType, ActionProtocol) -> StateType
public typealias EventEvaluation<StateType> = (EventProtocol, @escaping GetState<StateType>) -> Observable<ActionProtocol>
public typealias NextEventHandler<StateType> = (EventProtocol, @escaping GetState<StateType>) -> Void
public typealias NextActionHandler<StateType> = (ActionProtocol, @escaping GetState<StateType>) -> Void
