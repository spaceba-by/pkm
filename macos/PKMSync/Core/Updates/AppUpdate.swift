import Foundation

struct AppUpdate: Sendable, Equatable {
    let version: String
    let releaseNotes: String
    let downloadURL: URL
    let publishedAt: Date
    let assetSize: Int64
}
