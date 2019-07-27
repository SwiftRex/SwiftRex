#if canImport(Combine)
import Foundation

struct SomeError: Error, Equatable {
    let uuid = UUID()
}
#endif
