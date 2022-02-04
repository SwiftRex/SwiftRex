import UIKit
import RxSwift

class BaseMainTableViewCell: UITableViewCell {
  
  var disposeBag = DisposeBag()
  
  override func prepareForReuse() {
    super.prepareForReuse()
    disposeBag = DisposeBag()
  }
}
