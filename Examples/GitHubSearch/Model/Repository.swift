import Foundation

struct Repository: Equatable, CustomDebugStringConvertible, Codable {
    var name: String
    var url: URL

    init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

extension Repository {
    var debugDescription: String {
        return "\(name) | \(url)"
    }
}
