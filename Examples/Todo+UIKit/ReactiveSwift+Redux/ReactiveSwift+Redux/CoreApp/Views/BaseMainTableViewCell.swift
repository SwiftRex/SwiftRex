import UIKit
import ReactiveSwift

class BaseMainTableViewCell: UITableViewCell {
  
  private(set) var disposables = CompositeDisposable()
  
  override func prepareForReuse() {
    super.prepareForReuse()
    disposables.dispose()
    disposables = CompositeDisposable()
  }
}
