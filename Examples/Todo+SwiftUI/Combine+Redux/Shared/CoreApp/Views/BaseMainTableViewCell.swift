import UIKit
import Combine

class BaseMainTableViewCell: UITableViewCell {
  
  var cancellables: Set<AnyCancellable> = []
  
  override func prepareForReuse() {
    super.prepareForReuse()
    cancellables = []
  }
}
