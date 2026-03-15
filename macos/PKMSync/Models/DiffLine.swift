import Foundation

struct DiffLine: Identifiable, Sendable {
    let id: Int
    let text: String
    let type: DiffLineType
}

enum DiffLineType: Sendable {
    case context
    case added
    case removed
    case header
}
