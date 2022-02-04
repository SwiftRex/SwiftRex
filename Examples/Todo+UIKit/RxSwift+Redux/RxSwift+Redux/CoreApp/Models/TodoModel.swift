import Foundation

struct TodoModel: Codable, Identifiable, Equatable {
  var id: UUID
  var title: String
  var isCompleted: Bool
}
