import RxCocoa
import RxSwift
import SwiftRex
import UIKit

class RepositorySearchViewController: UIViewController {
    @IBOutlet private var tableView: UITableView!
    private let searchController = UISearchController(searchResultsController: nil)

    var presenter: RepositorySearchPresenterProtocol!
    let dataSource: BehaviorSubject<[String]> = .init(value: [])
    var disposeBag = DisposeBag()

    override func viewDidLoad() {
        tableView.scrollIndicatorInsets.top = tableView.contentInset.top
        searchController.dimsBackgroundDuringPresentation = false
        navigationItem.searchController = searchController

        let input = RepositorySearchViewInput (
            queryText: searchController.searchBar.rx.text.asObservable(),
            scrollOffset: tableView.rx.contentOffset.asObservable(),
            frame: tableView.rx.frame,
            contentSize: tableView.rx.contentSize)

        presenter
            .bind(input: input)
            .asDriver(onErrorJustReturn: RepositorySearchViewModel.default)
            .drive(onNext: update)
            .disposed(by: disposeBag)

        dataSource
            .bind(to: tableView.rx.items(cellIdentifier: "cell")) { indexPath, name, cell in
                cell.textLabel?.text = name
            }
            .disposed(by: disposeBag)
    }

    func update(viewModel: RepositorySearchViewModel) {
        searchController.searchBar.text = viewModel.query
        dataSource.onNext(viewModel.repositories)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.setAnimationsEnabled(false)
        searchController.isActive = true
        searchController.isActive = false
        UIView.setAnimationsEnabled(true)
    }
}
