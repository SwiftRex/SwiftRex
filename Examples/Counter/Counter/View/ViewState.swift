struct ViewState {
    var text: String!
    let isSpinnerHidden: Bool
    let isIncreaseButtonEnabled: Bool
    let isDecreaseButtonEnabled: Bool

    init(from state: GlobalState) {
        isSpinnerHidden = !state.isLoading
        isIncreaseButtonEnabled = !state.isLoading
        isDecreaseButtonEnabled = !state.isLoading
        text = format(integer: state.value)
    }

    private func format(integer: Int) -> String {
        return String(integer)
    }
}
