import UIKit

class ButtonReloadMainTableViewCell: BaseMainTableViewCell {
  
  let buttonReload = UIButton(type: .system)
  let activityIndicator = UIActivityIndicatorView()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // setup view
    contentView.isUserInteractionEnabled = false
    // buttonReload
    buttonReload.setTitle("Reload", for: .normal)
    buttonReload.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    buttonReload.setTitleColor(.black, for: .normal)
    buttonReload.translatesAutoresizingMaskIntoConstraints = false
    addSubview(buttonReload)
    // activityIndicator
    activityIndicator.hidesWhenStopped = true
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    addSubview(activityIndicator)
    // constraint
    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
      activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
      buttonReload.centerXAnchor.constraint(equalTo: centerXAnchor),
      buttonReload.centerYAnchor.constraint(equalTo: centerYAnchor),
    ])
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

