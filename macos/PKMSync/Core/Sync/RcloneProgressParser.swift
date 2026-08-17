import Foundation

/// Incrementally turns rclone's `--verbose --stats` output into `SyncProgress`
/// snapshots so long-running syncs can report what they are doing.
///
/// Two kinds of line carry progress. Prefixed log lines announce phases and
/// completed objects:
///
///     2026/08/12 11:37:28 INFO  : Building Path1 and Path2 listings
///     2026/08/12 11:37:28 INFO  : sub/deep.md: Copied (server-side copy)
///
/// The periodic stats block carries counts and throughput. rclone logs it as a
/// single multi-line `INFO` message whose body starts with a newline, so the log
/// prefix sits alone on the preceding line and none of the stats lines below
/// carry one:
///
///     2026/08/12 11:37:28 INFO  :
///     Transferred:      1.402 MiB / 38.147 MiB, 4%, 2.027 MiB/s, ETA 17s
///     Checks:               0 / 0, -, Listed 1
///     Transferred:          0 / 1, 0%
///     Transferring:
///      *                          blob.bin:  3% / 38.147 MiB, 0 B/s, -
///
/// Thread-safe via an internal lock, but callers must still deliver lines in
/// order: this is a state machine and the `Transferring:` block spans lines.
/// `ProcessRunner` guarantees ordered, serial delivery.
final class RcloneProgressParser: @unchecked Sendable {
    private let lock = NSLock()
    private var progress = SyncProgress()
    private var inTransferringBlock = false
    private var capturedInFlightObject = false

    // Instance-level because `Regex` is not `Sendable`; only touched under `lock`.
    private let logPrefix = /^\d{4}\/\d{2}\/\d{2} \d{2}:\d{2}:\d{2} [A-Z]+ *: */
    private let ansiEscape = /\x1B\[[0-9;]*[a-zA-Z]/

    /// Feeds one line of rclone output.
    /// - Returns: An updated snapshot when the line advanced progress, else `nil`.
    func consume(line: String) -> SyncProgress? {
        lock.lock()
        defer { lock.unlock() }

        // Strip the log prefix up front and feed the bare message to both paths.
        // Stats lines are unprefixed in practice, but tolerating a prefix costs
        // nothing and keeps parsing working if a user's own rclone config emits
        // them differently (`--stats-one-line` puts them on the `INFO` line).
        let message = messageBody(of: strippingANSI(line))

        if let updated = consumeStatsBlockLine(message) {
            return updated
        }

        if let phase = Self.phase(from: message) {
            progress.phase = phase
            // Phase boundaries make the previous object stale.
            progress.currentObject = nil
            return progress
        }

        if let object = Self.completedObject(from: message) ?? Self.changedObject(from: message) {
            progress.currentObject = object
            return progress
        }

        return nil
    }

    /// Handles the periodic stats block. Takes the message body with any log
    /// prefix already stripped, so a prefixed stats line parses the same way.
    /// - Returns: An updated snapshot, or `nil` if the line is not a stats line.
    private func consumeStatsBlockLine(_ trimmed: String) -> SyncProgress? {
        if trimmed == "Transferring:" {
            inTransferringBlock = true
            capturedInFlightObject = false
            return nil
        }

        if inTransferringBlock {
            if trimmed.hasPrefix("*") {
                // Several objects can be in flight; the first is representative.
                guard !capturedInFlightObject else { return nil }
                capturedInFlightObject = true
                if let inFlight = Self.inFlightTransfer(from: trimmed) {
                    // This names the object actually in flight, so it is the most
                    // timely source — except that rclone truncates long names here,
                    // in which case the full path from the log lines is better.
                    if !Self.looksTruncated(inFlight.object) || progress.currentObject == nil {
                        progress.currentObject = inFlight.object
                    }
                    progress.speed = inFlight.speed
                    progress.eta = inFlight.eta
                    return progress
                }
                return nil
            }
            inTransferringBlock = false
        }

        if trimmed.hasPrefix("Transferred:") {
            return consumeTransferredLine(trimmed)
        }

        if trimmed.hasPrefix("Checks:"), let listed = Self.listedCount(from: trimmed) {
            progress.objectsListed = listed
            return progress
        }

        return nil
    }

    /// rclone prints two `Transferred:` lines per stats block — bytes then file
    /// counts. The byte line always carries percent/speed/ETA fields too, so the
    /// comma count tells them apart.
    private func consumeTransferredLine(_ trimmed: String) -> SyncProgress? {
        let remainder = trimmed
            .dropFirst("Transferred:".count)
            .trimmingCharacters(in: .whitespaces)
        let fields = remainder
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        guard let pair = fields.first,
              let (done, total) = Self.slashPair(from: pair)
        else { return nil }

        if fields.count >= 3 {
            guard let bytesDone = Self.parseBytes(done),
                  let bytesTotal = Self.parseBytes(total)
            else { return nil }
            progress.bytesTransferred = bytesDone
            progress.bytesTotal = bytesTotal
            progress.speed = fields[2].isEmpty ? nil : fields[2]
            progress.eta = Self.parseETA(fields.count > 3 ? fields[3] : nil)
            return progress
        }

        guard let filesDone = Int(done), let filesTotal = Int(total) else { return nil }
        progress.filesDone = filesDone
        progress.filesTotal = filesTotal
        return progress
    }

    // MARK: - Line parsing

    /// Strips the `2026/08/12 11:37:28 INFO  : ` prefix, if present.
    private func messageBody(of line: String) -> String {
        guard let match = line.firstMatch(of: logPrefix) else {
            return line.trimmingCharacters(in: .whitespaces)
        }
        return String(line[match.range.upperBound...])
            .trimmingCharacters(in: .whitespaces)
    }

    /// rclone emits ANSI colour codes even when its output is a pipe. `SyncService`
    /// passes `--color NEVER`, but strip them anyway so a user's own rclone config
    /// cannot break parsing.
    private func strippingANSI(_ line: String) -> String {
        line.replacing(ansiEscape, with: "")
    }

    /// A normal run announces transfers as "Applying changes"; a resync names the
    /// direction it is copying instead.
    private static let applyingChangesPrefixes = [
        "Applying changes",
        "Copying Path1 files to Path2",
        "Copying Path2 files to Path1",
    ]

    private static func phase(from message: String) -> SyncPhase? {
        if message.hasPrefix("Synching Path1") {
            return .starting
        }
        if message.hasPrefix("Building Path1 and Path2 listings") {
            return .buildingListings
        }
        if message.hasSuffix("checking for diffs") {
            let path = message
                .replacingOccurrences(of: " checking for diffs", with: "")
                .trimmingCharacters(in: .whitespaces)
            return .checkingDiffs(path: path)
        }
        if applyingChangesPrefixes.contains(where: message.hasPrefix) {
            return .applyingChanges
        }
        if message.hasSuffix("pdating listings") {
            // "Updating listings" and resync's "Resync updating listings".
            return .updatingListings
        }
        if message.hasPrefix("Validating listings") {
            return .validating
        }
        if message.hasPrefix("Bisync successful") {
            return .finishing
        }
        return nil
    }

    /// Actions that mean rclone touched a real object, as opposed to the
    /// directory bookkeeping (`Set directory modification time`) that would
    /// otherwise flicker past as the "current" file.
    private static let objectActions = [
        "Copied",
        "Moved",
        "Deleted",
        "Updated modification time",
        "Multi-thread Copied",
    ]

    /// Parses `sub/deep.md: Copied (server-side copy)`.
    private static func completedObject(from message: String) -> String? {
        guard let separator = message.range(of: ": ", options: .backwards) else { return nil }
        let action = String(message[separator.upperBound...])
        guard objectActions.contains(where: { action.hasPrefix($0) }) else { return nil }

        let object = String(message[..<separator.lowerBound])
        return object.isEmpty ? nil : object
    }

    /// Descriptors on bisync's diff-scan lines that name a real file. Excludes
    /// `Queue copy to` (absolute destination paths) and `Do queued copies to`
    /// (names a side, not a file).
    private static let changeDescriptors = [
        "File is new",
        "File changed",
        "File was deleted",
        "File is newer",
        "File is older",
    ]

    /// Parses `- Path1    File is new    - big/blob.bin`.
    ///
    /// Uses the *first* ` - ` as the separator so filenames containing ` - ` survive.
    private static func changedObject(from message: String) -> String? {
        guard message.hasPrefix("- "),
              let separator = message.range(of: " - ")
        else { return nil }

        let descriptor = String(message[..<separator.lowerBound])
        guard changeDescriptors.contains(where: { descriptor.contains($0) }) else { return nil }

        let object = String(message[separator.upperBound...])
            .trimmingCharacters(in: .whitespaces)
        return object.isEmpty ? nil : object
    }

    private struct InFlightTransfer {
        let object: String
        let speed: String?
        let eta: String?
    }

    /// Parses ` *    blob.bin:  3% / 38.147 MiB, 2.027 MiB/s, 17s`.
    private static func inFlightTransfer(from line: String) -> InFlightTransfer? {
        let body = line.dropFirst().trimmingCharacters(in: .whitespaces)
        guard let separator = body.range(of: ": ", options: .backwards) else { return nil }

        let object = String(body[..<separator.lowerBound]).trimmingCharacters(in: .whitespaces)
        guard !object.isEmpty else { return nil }

        let fields = String(body[separator.upperBound...])
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        return InFlightTransfer(
            object: object,
            speed: fields.count > 1 ? fields[1] : nil,
            eta: parseETA(fields.count > 2 ? fields[2] : nil)
        )
    }

    /// rclone elides the middle of long names in the `Transferring:` block, e.g.
    /// `a-very-long-directory-…runcated-somewhere.bin`.
    private static func looksTruncated(_ object: String) -> Bool {
        object.contains("…") || object.contains("...")
    }

    /// Parses `Listed 18` out of `Checks:  11 / 11, 100%, Listed 18`.
    private static func listedCount(from line: String) -> Int? {
        guard let range = line.range(of: "Listed ") else { return nil }
        let digits = line[range.upperBound...].prefix(while: \.isNumber)
        return Int(digits)
    }

    /// Splits `1.402 MiB / 38.147 MiB` or `0 / 1`.
    private static func slashPair(from text: String) -> (String, String)? {
        let parts = text.components(separatedBy: " / ")
        guard parts.count == 2 else { return nil }
        return (
            parts[0].trimmingCharacters(in: .whitespaces),
            parts[1].trimmingCharacters(in: .whitespaces)
        )
    }

    /// Ordered longest-suffix-first so `KiB` is not matched as `B`.
    private static let byteMultipliers: [(suffix: String, multiplier: Double)] = [
        ("Bytes", 1),
        ("TiB", 1_099_511_627_776),
        ("GiB", 1_073_741_824),
        ("MiB", 1_048_576),
        ("KiB", 1024),
        ("TB", 1_000_000_000_000),
        ("GB", 1_000_000_000),
        ("MB", 1_000_000),
        ("kB", 1000),
        ("B", 1),
    ]

    static func parseBytes(_ text: String) -> Int64? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        for (suffix, multiplier) in byteMultipliers where trimmed.hasSuffix(suffix) {
            let number = trimmed
                .dropLast(suffix.count)
                .trimmingCharacters(in: .whitespaces)
            guard let value = Double(number) else { return nil }
            return Int64(value * multiplier)
        }
        return nil
    }

    /// rclone writes an unknown ETA as `-`, and prefixes it with `ETA` in the
    /// summary line but not in the per-transfer line.
    private static func parseETA(_ field: String?) -> String? {
        guard let field else { return nil }
        let value = field
            .replacingOccurrences(of: "ETA", with: "")
            .trimmingCharacters(in: .whitespaces)
        return value.isEmpty || value == "-" ? nil : value
    }
}
