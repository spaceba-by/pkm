import Foundation

/// Sort order options for document lists
enum DocumentSortOrder: String, CaseIterable {
    case modifiedDate
    case createdDate

    var displayName: String {
        switch self {
        case .modifiedDate: "Modified Date"
        case .createdDate: "Created Date"
        }
    }
}
