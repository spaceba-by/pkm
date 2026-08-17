import Foundation

/// A stage of an rclone `bisync` run, derived from its `INFO` log lines.
///
/// bisync spends most of a large sync outside of transferring — building and
/// validating listings — so the phase is what makes a long run legible.
enum SyncPhase: Sendable, Equatable {
    case starting
    case buildingListings
    case checkingDiffs(path: String)
    case applyingChanges
    case updatingListings
    case validating
    case finishing

    var label: String {
        switch self {
        case .starting:
            "Starting sync..."
        case .buildingListings:
            "Building listings"
        case let .checkingDiffs(path):
            "Checking \(Self.friendlyName(for: path)) for changes"
        case .applyingChanges:
            "Transferring files"
        case .updatingListings:
            "Updating listings"
        case .validating:
            "Validating listings"
        case .finishing:
            "Finishing up"
        }
    }

    /// rclone labels the two sides `Path1`/`Path2`; the vault is always Path1
    /// and the bucket Path2 (see `SyncService.buildArguments`).
    private static func friendlyName(for path: String) -> String {
        switch path {
        case "Path1":
            "vault"
        case "Path2":
            "cloud"
        default:
            path
        }
    }
}

/// A snapshot of an in-flight rclone run, parsed from its output stream.
struct SyncProgress: Sendable, Equatable {
    var phase: SyncPhase = .starting
    /// The object rclone most recently reported working on, as a vault-relative path.
    var currentObject: String?
    var filesDone: Int = 0
    var filesTotal: Int = 0
    var bytesTransferred: Int64 = 0
    var bytesTotal: Int64 = 0
    /// Objects enumerated so far — the only forward motion visible while listing.
    var objectsListed: Int = 0
    var speed: String?
    var eta: String?

    /// Byte-based completion, falling back to file counts.
    ///
    /// `nil` when rclone hasn't reported a total yet, which is the cue for the
    /// UI to show an indeterminate bar rather than a misleading zero.
    var fractionCompleted: Double? {
        if bytesTotal > 0 {
            return min(1, Double(bytesTransferred) / Double(bytesTotal))
        }
        if filesTotal > 0 {
            return min(1, Double(filesDone) / Double(filesTotal))
        }
        return nil
    }

    /// A one-line summary of counts, throughput and ETA for the popover.
    var statsLine: String? {
        var parts: [String] = []

        if filesTotal > 0 {
            parts.append("\(filesDone)/\(filesTotal) files")
        }

        if bytesTotal > 0 {
            let done = bytesTransferred.formatted(.byteCount(style: .file))
            let total = bytesTotal.formatted(.byteCount(style: .file))
            parts.append("\(done) of \(total)")
        } else if objectsListed > 0 {
            parts.append("\(objectsListed) listed")
        }

        if let speed, !speed.hasPrefix("0 B") {
            parts.append(speed)
        }

        if let eta {
            parts.append("ETA \(eta)")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
