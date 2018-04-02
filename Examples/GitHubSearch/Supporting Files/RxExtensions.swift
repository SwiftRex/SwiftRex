import RxCocoa
import RxSwift
import UIKit

extension Reactive where Base: UIView {
    var frame: Observable<CGRect> {
        return base.rx
            .observe(CGRect.self, #keyPath(UIView.bounds))
            .map { [unowned base] _ in base.frame }
    }
}

extension Reactive where Base: UIScrollView {
    var contentSize: Observable<CGSize> {
        return base.rx
            .observe(CGSize.self, #keyPath(UIScrollView.contentSize))
            .map { $0 ?? .zero }
    }
}
