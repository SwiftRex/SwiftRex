public typealias GetState<StateType> = () -> StateType
public typealias ReducerFunction<StateType> = (StateType, Action) -> StateType
public typealias EventEvaluation<StateType> = (Event, @escaping GetState<StateType>) -> Observable<Action>

public class Observable<T> {

}
