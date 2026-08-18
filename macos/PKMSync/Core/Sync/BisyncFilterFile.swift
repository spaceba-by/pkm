import Foundation

/// Manages the rclone filters file handed to `bisync --filters-file`.
///
/// The `_agent/` exclusion is not optional: agent output is pulled one-way from
/// S3 by ``SyncService`` so the remote stays authoritative, and bisync must not
/// also be managing those paths.
enum BisyncFilterFile {
    static let defaultContents = """
    # rclone bisync filters for the PKM vault (managed by PKMSync).
    #
    # Edit freely -- bisync MD5-hashes this file and will require a --resync the
    # next time it changes, which is what stops newly excluded files from looking
    # "deleted" and getting deleted for real.

    # Agent output: pulled one-way from S3 by PKMSync, never pushed back.
    - /_agent/
    - /_agent/**

    # Obsidian working state: per-device and rewritten constantly.
    - /.obsidian/workspace*.json
    - /.obsidian/**/cache*
    - /.obsidian/**/*.log

    # Local scratch.
    - /.trash/**
    - .DS_Store
    - *.tmp
    - *.swp
    - .sync_conflict*

    """

    /// Creates the filters file with ``defaultContents`` when it does not exist.
    ///
    /// An existing file is never modified -- users are expected to customise it,
    /// and rewriting it would trip bisync's filter-change guard on every launch.
    static func ensureExists(
        at path: String,
        fileManager: FileManager = .default
    ) throws {
        guard !fileManager.fileExists(atPath: path) else { return }

        let url = URL(fileURLWithPath: path)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try defaultContents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Default location for the managed filters file.
    static func defaultPath(fileManager: FileManager = .default) -> String {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return support
            .appendingPathComponent("PKMSync")
            .appendingPathComponent("bisync-filter.txt")
            .path
    }
}
