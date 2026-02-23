import Foundation
import SwiftData

/// Service for caching documents locally using SwiftData
@MainActor
final class DocumentCacheService: @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// Maximum age for cached items (in seconds)
    private let maxCacheAge: TimeInterval = 3600 // 1 hour

    init() throws {
        let schema = Schema([CachedDocument.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
    }

    /// For testing - use in-memory storage
    init(inMemory: Bool) throws {
        let schema = Schema([CachedDocument.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
    }

    func cacheDocuments(_ documents: [Document]) {
        for document in documents {
            // Check if already cached
            let id = document.id
            let descriptor = FetchDescriptor<CachedDocument>(
                predicate: #Predicate { $0.id == id }
            )

            if let existing = try? modelContext.fetch(descriptor).first {
                // Update existing
                existing.title = document.title
                existing.content = document.content
                existing.classification = document.metadata.classification.rawValue
                existing.modified = document.metadata.modified
                existing.cachedAt = Date()
                if let tags = try? JSONEncoder().encode(document.metadata.tags),
                   let tagsString = String(data: tags, encoding: .utf8) {
                    existing.tagsJSON = tagsString
                }
            } else {
                // Insert new
                let cached = CachedDocument(from: document)
                modelContext.insert(cached)
            }
        }

        try? modelContext.save()
    }

    func getCachedDocuments(classification: DocumentClassification?) -> [Document]? {
        var descriptor = FetchDescriptor<CachedDocument>(
            sortBy: [SortDescriptor(\.modified, order: .reverse)]
        )

        if let classification {
            let classValue = classification.rawValue
            descriptor.predicate = #Predicate { $0.classification == classValue }
        }

        descriptor.fetchLimit = 100

        guard let cached = try? modelContext.fetch(descriptor), !cached.isEmpty else {
            return nil
        }

        // Check if cache is fresh
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        let freshCache = cached.filter { $0.cachedAt > cutoff }

        guard !freshCache.isEmpty else {
            return nil
        }

        return freshCache.map { $0.toDocument() }
    }

    func getCachedDocument(id: String) -> Document? {
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.id == id }
        )

        guard let cached = try? modelContext.fetch(descriptor).first else {
            return nil
        }

        // Check freshness
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        guard cached.cachedAt > cutoff else {
            return nil
        }

        return cached.toDocument()
    }

    func clearCache() {
        try? modelContext.delete(model: CachedDocument.self)
        try? modelContext.save()
    }

    func clearStaleCache() {
        let cutoff = Date().addingTimeInterval(-maxCacheAge)
        let descriptor = FetchDescriptor<CachedDocument>(
            predicate: #Predicate { $0.cachedAt < cutoff }
        )

        if let stale = try? modelContext.fetch(descriptor) {
            for item in stale {
                modelContext.delete(item)
            }
            try? modelContext.save()
        }
    }
}
