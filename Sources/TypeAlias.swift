public typealias ReducerFunction<StateType> = (StateType, Action) -> StateType
public typealias EventEvaluation<StateType> = (Event, @escaping () -> StateType) -> Observable<Action>

public class Observable<T> {

}
