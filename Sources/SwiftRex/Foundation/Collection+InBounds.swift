import Foundation

extension Collection {
    func inBounds(_ index: Index) -> Bool {
        index < endIndex && index >= startIndex
    }
}
