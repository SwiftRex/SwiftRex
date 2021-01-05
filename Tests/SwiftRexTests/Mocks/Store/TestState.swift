import Foundation
import SwiftRex

struct TestState: Equatable {
    var value = UUID()
    var name = ""
}

struct AppState: Equatable {
    let testState: TestState
    var list: [Item]

    struct Item: Equatable, Identifiable {
        let id: Int
        let name: String
    }
}
