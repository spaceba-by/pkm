import Foundation
import Observation

@MainActor
@Observable
final class ConflictDetailViewModel {
    let conflict: ConflictFile
    let vaultPath: String
    private let diffService: DiffServiceProtocol
    private let conflictService: ConflictServiceProtocol

    private(set) var diffLines: [DiffLine] = []
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var isResolved = false

    var onResolved: (() -> Void)?

    init(
        conflict: ConflictFile,
        vaultPath: String,
        diffService: DiffServiceProtocol = DiffService(),
        conflictService: ConflictServiceProtocol = ConflictService()
    ) {
        self.conflict = conflict
        self.vaultPath = vaultPath
        self.diffService = diffService
        self.conflictService = conflictService
    }

    func loadDiff() async {
        isLoading = true
        error = nil

        let service = diffService
        let original = conflict.originalPath
        let conflictPath = conflict.conflictPath

        do {
            let lines = try await Task.detached {
                try await service.diff(originalPath: original, conflictPath: conflictPath)
            }.value
            diffLines = lines
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func resolve(_ resolution: ConflictResolution) {
        do {
            try conflictService.resolveConflict(conflict, resolution: resolution)
            isResolved = true
            onResolved?()
        } catch {
            self.error = "Failed to resolve: \(error.localizedDescription)"
        }
    }
}
