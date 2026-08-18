import Foundation

struct RcloneParseResult: Sendable, Equatable {
    let filesTransferred: Int
    let filesChecked: Int
    let elapsedSeconds: TimeInterval
    let errors: Int
    let errorMessages: [String]
    let needsResync: Bool

    init(
        filesTransferred: Int = 0,
        filesChecked: Int = 0,
        elapsedSeconds: TimeInterval = 0,
        errors: Int = 0,
        errorMessages: [String] = [],
        needsResync: Bool = false
    ) {
        self.filesTransferred = filesTransferred
        self.filesChecked = filesChecked
        self.elapsedSeconds = elapsedSeconds
        self.errors = errors
        self.errorMessages = errorMessages
        self.needsResync = needsResync
    }
}

enum RcloneOutputParser {
    static func parse(stdout: String, stderr: String) -> RcloneParseResult {
        let combined = stdout + "\n" + stderr
        let lines = combined.components(separatedBy: .newlines)

        var filesTransferred = 0
        var filesChecked = 0
        var elapsedSeconds: TimeInterval = 0
        var errors = 0
        var errorMessages: [String] = []
        var needsResync = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Transferred:"), containsSizeUnit(trimmed) {
                // This is the bytes/size transferred line, skip
                continue
            } else if let value = extractStatValue(from: trimmed, prefix: "Transferred:") {
                filesTransferred = value
            } else if let value = extractStatValue(from: trimmed, prefix: "Checks:") {
                filesChecked = value
            } else if let value = extractStatValue(from: trimmed, prefix: "Errors:") {
                errors = value
            } else if let seconds = extractElapsed(from: trimmed) {
                elapsedSeconds = seconds
            } else if let failure = failureMessage(in: trimmed) {
                errorMessages.append(failure)
            }

            if trimmed.contains("cannot find prior Path1 or Path2 listings") {
                needsResync = true
            }
        }

        return RcloneParseResult(
            filesTransferred: filesTransferred,
            filesChecked: filesChecked,
            elapsedSeconds: elapsedSeconds,
            errors: errors,
            errorMessages: errorMessages,
            needsResync: needsResync
        )
    }

    // MARK: - Failures

    /// Log levels that always mean the run went wrong. `NOTICE` is deliberately
    /// absent: rclone uses it for routine remarks as well as for the lines below.
    private static let failureLevels: Set<String> = ["ERROR", "CRITICAL", "FATAL"]

    /// bisync reports its *fatal* errors at `NOTICE`, so the level alone cannot
    /// classify them. A failed run ends with lines like:
    ///
    ///     2026/08/17 17:52:53 NOTICE: Failed to bisync: prior lock file found: ...
    ///     2026/08/17 17:52:53 NOTICE: Bisync aborted. Must run --resync to recover.
    private static let failurePrefixes = [
        "Failed to",
        "Bisync critical error",
        "Bisync aborted",
    ]

    /// The human-readable failure in `line`, or `nil` if it does not report one.
    ///
    /// Returns the message with rclone's `2026/08/17 17:52:53 NOTICE: ` prefix
    /// stripped: the log row already shows the time, and the level adds nothing
    /// once the entry is marked failed.
    private static func failureMessage(in line: String) -> String? {
        let (level, message) = splitLogPrefix(line)
        guard !message.isEmpty else { return nil }

        if let level, failureLevels.contains(level) {
            return message
        }
        if failurePrefixes.contains(where: message.hasPrefix) {
            return message
        }
        return nil
    }

    /// rclone's fixed-width `2026/08/17 17:57:53 ` timestamp.
    private static let timestampPattern = "dddd/dd/dd dd:dd:dd "

    /// Splits an rclone log line into its level and message. Both halves of the
    /// prefix are optional — stats lines carry neither.
    private static func splitLogPrefix(_ line: String) -> (level: String?, message: String) {
        let body = droppingTimestamp(Substring(line))

        guard let colon = body.firstIndex(of: ":") else {
            return (nil, String(body))
        }
        let level = body[..<colon].trimmingCharacters(in: .whitespaces)
        // Levels are all-caps, which is what tells `ERROR : ...` apart from a
        // message that merely happens to contain a colon.
        guard !level.isEmpty, level.allSatisfy({ $0.isLetter && $0.isUppercase }) else {
            return (nil, String(body))
        }

        let message = body[body.index(after: colon)...]
            .trimmingCharacters(in: .whitespaces)
        return (level, message)
    }

    private static func droppingTimestamp(_ line: Substring) -> Substring {
        guard line.count >= timestampPattern.count else { return line }

        let matches = zip(line, timestampPattern).allSatisfy { character, token in
            token == "d" ? character.isNumber : character == token
        }
        return matches ? line.dropFirst(timestampPattern.count) : line
    }

    // MARK: - Stats

    /// "B" matters: a small sync reports "Transferred: 31 B / 31 B, 100%", which
    /// without it is mistaken for the file-count line.
    private static let sizeUnits = [
        "Bytes", "KiB", "MiB", "GiB", "TiB", "kB", "MB", "GB", "TB", "B",
    ]

    private static func containsSizeUnit(_ line: String) -> Bool {
        sizeUnits.contains { line.contains($0) }
    }

    private static func extractStatValue(from line: String, prefix: String) -> Int? {
        guard line.hasPrefix(prefix) else { return nil }
        let remainder = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        let numberString = remainder.prefix(while: { $0.isNumber })
        return Int(numberString)
    }

    private static func extractElapsed(from line: String) -> TimeInterval? {
        guard line.hasPrefix("Elapsed time:") else { return nil }
        let remainder = line.dropFirst("Elapsed time:".count).trimmingCharacters(in: .whitespaces)

        // Parse formats like "1.234s", "1m2.345s", "1h2m3.456s"
        var total: TimeInterval = 0
        var current = remainder[...]

        if let hRange = current.range(of: "h") {
            if let hours = Double(current[..<hRange.lowerBound]) {
                total += hours * 3600
            }
            current = current[hRange.upperBound...]
        }
        if let mRange = current.range(of: "m") {
            if let minutes = Double(current[..<mRange.lowerBound]) {
                total += minutes * 60
            }
            current = current[mRange.upperBound...]
        }
        if let sRange = current.range(of: "s") {
            if let seconds = Double(current[..<sRange.lowerBound]) {
                total += seconds
            }
        }

        return total
    }
}
