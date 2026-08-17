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
            } else if trimmed.contains("ERROR") || trimmed.hasPrefix("Failed to") {
                errorMessages.append(trimmed)
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
