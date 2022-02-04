import UIKit
import SwiftUI

class CreateTitleMainTableViewCell: BaseMainTableViewCell {
  
  let createButton = UIButton(type: .system)
  let titleTextField = UITextField()
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    // setup
    contentView.isUserInteractionEnabled = false
    // createButton
    createButton.setTitle("Create", for: .normal)
    createButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
    createButton.setTitleColor(UIColor(Color.green), for: .normal)
    createButton.translatesAutoresizingMaskIntoConstraints = false
    // titleTextField
    titleTextField.placeholder = "title"
    // stackView
    let stackView = UIStackView(arrangedSubviews: [
      titleTextField,
      createButton,
    ])
    stackView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(stackView)
    // constraint
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
      stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

