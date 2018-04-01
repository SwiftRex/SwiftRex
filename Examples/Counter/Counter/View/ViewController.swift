import RxSwift
import SwiftRex
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var decreaseButton: UIButton!
    @IBOutlet private var increaseButton: UIButton!
    @IBOutlet private var valueLabel: UILabel!
    @IBOutlet private var spinnerView: UIActivityIndicatorView!
    private var disposeBag = DisposeBag()

    var stateProvider: GlobalStateProvider!
    var eventHandler: EventHandler!

    override func viewDidLoad() {
        stateProvider
            .distinctUntilChanged()
            .map(ViewState.init)
            .subscribe(onNext: { [weak self] in self?.update(viewState: $0) })
            .disposed(by: disposeBag)
    }

    func update(viewState: ViewState) {
        decreaseButton.isEnabled = viewState.isDecreaseButtonEnabled
        increaseButton.isEnabled = viewState.isIncreaseButtonEnabled
        spinnerView.isHidden = viewState.isSpinnerHidden
        valueLabel.text = viewState.text
    }

    @IBAction private func decreaseButtonEvent(_ sender: UIButton) {
        eventHandler.dispatch(CounterEvent.decreaseRequest)
    }

    @IBAction private func increaseButtonEvent(_ sender: UIButton) {
        eventHandler.dispatch(CounterEvent.increaseRequest)
    }
}
