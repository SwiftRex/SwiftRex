import RxCocoa
import RxSwift
import SwiftRex
import UIKit

class ViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    private let searchController = UISearchController(searchResultsController: nil)
    private var disposeBag = DisposeBag()
    typealias Event = SwiftRex.Event

    var stateProvider: GlobalStateProvider!
    var eventHandler: EventHandler!

    override func viewDidLoad() {
        tableView.scrollIndicatorInsets.top = tableView.contentInset.top
        searchController.dimsBackgroundDuringPresentation = false
        navigationItem.searchController = searchController

        let viewState = stateProvider
            .share(replay: 1, scope: .forever)
            .distinctUntilChanged()
            .map(ViewState.init)

        viewState
            .map { $0.repositories }
            .bind(to: tableView.rx.items(cellIdentifier: "cell")) { indexPath, name, cell in
                cell.textLabel?.text = name
            }
            .disposed(by: disposeBag)

        viewState
            .subscribe(onNext: { [weak self] in self?.update(viewState: $0) })
            .disposed(by: disposeBag)

        searchController.searchBar.rx.text
            .throttle(0.3, scheduler: MainScheduler.instance)
            .map(RepositorySearchEvent.changedQuery)
            .subscribe(onNext: eventHandler.dispatch)
            .disposed(by: disposeBag)

        tableView.rx.contentOffset
            .filter { [weak self] offset in
                guard let strongSelf = self,
                    strongSelf.tableView.frame.height > 0 else { return false }
                return offset.y + strongSelf.tableView.frame.height >= strongSelf.tableView.contentSize.height - 100
            }
            .map { _ in RepositorySearchEvent.approachingEndOfCurrentPage }
            .subscribe(onNext: eventHandler.dispatch)
            .disposed(by: disposeBag)
    }

    func update(viewState: ViewState) {
        searchController.searchBar.text = viewState.query
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.setAnimationsEnabled(false)
        searchController.isActive = true
        searchController.isActive = false
        UIView.setAnimationsEnabled(true)
    }
}
