import Foundation

/// Manages the rclone filters file handed to `bisync --filters-file`.
///
/// The `_agent/` exclusion is not optional: agent output is pulled one-way from
/// S3 by ``SyncService`` so the remote stays authoritative, and bisync must not
/// also be managing those paths. ``prepare(at:fileManager:)`` enforces it on
/// user-supplied filter files too.
enum BisyncFilterFile {
    /// The rule that keeps bisync away from agent output.
    static let agentExclusionRule = "- /_agent/**"

    /// Prepended to a filters file that lacks an effective ``agentExclusionRule``.
    /// rclone applies the first matching rule, so it must come before any `+`.
    static let agentExclusionBlock = """
    # Agent output: pulled one-way from S3 by PKMSync, never pushed back.
    # Added automatically -- PKMSync requires this exclusion.
    - /_agent/
    \(agentExclusionRule)

    """

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
    /// An existing file is not rewritten -- users are expected to customise it,
    /// and rewriting it would trip bisync's filter-change guard on every launch.
    private static func ensureExists(
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

    /// Makes the filters file at `path` safe for bisync: creates it with
    /// ``defaultContents`` if missing, and prepends ``agentExclusionBlock`` if
    /// the existing file does not exclude `_agent/` ahead of any include rule.
    ///
    /// Apart from that one block, an existing file is left untouched.
    ///
    /// - Returns: `true` if an existing file was modified. bisync's filter-change
    ///   guard will then refuse to run until a `--resync`.
    @discardableResult
    static func prepare(
        at path: String,
        fileManager: FileManager = .default
    ) throws -> Bool {
        try ensureExists(at: path, fileManager: fileManager)

        let contents = try String(contentsOfFile: path, encoding: .utf8)
        guard !excludesAgent(contents) else { return false }

        try (agentExclusionBlock + contents).write(
            toFile: path,
            atomically: true,
            encoding: .utf8
        )
        return true
    }

    /// Whether `contents` excludes `_agent/` before any `+` rule could
    /// re-include it. Earlier `-` rules only exclude more, so they are harmless.
    static func excludesAgent(_ contents: String) -> Bool {
        for line in contents.components(separatedBy: .newlines) {
            let rule = line.trimmingCharacters(in: .whitespaces)
            if rule == agentExclusionRule {
                return true
            }
            if rule.hasPrefix("+") {
                return false
            }
        }
        return false
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
