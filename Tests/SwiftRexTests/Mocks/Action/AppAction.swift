import Foundation
import SwiftRex

enum AppAction: Equatable {
    case foo
    case bar(Bar)

    enum Bar: Equatable {
        case alpha
        case bravo
        case charlie
        case delta
        case echo
    }
}
