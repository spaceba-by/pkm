import Foundation

struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    var description: String {
        "\(major).\(minor).\(patch)"
    }

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(string: String) {
        // Strip common prefixes like "v", "macos-v", etc.
        let cleaned = Self.stripPrefix(string)
        let parts = cleaned.split(separator: ".")
        guard parts.count >= 2,
              let major = Int(parts[0]),
              let minor = Int(parts[1])
        else { return nil }
        let patch = parts.count >= 3 ? Int(parts[2]) ?? 0 : 0
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    private static func stripPrefix(_ string: String) -> String {
        var s = string
        // Handle prefixes like "macos-v", "v", "macos-"
        if let range = s.range(of: #"^[a-zA-Z-]*v?"#, options: .regularExpression) {
            let prefix = s[range]
            // Only strip if the remainder starts with a digit
            let remainder = s[range.upperBound...]
            if let first = remainder.first, first.isNumber {
                s = String(remainder)
            } else if prefix.hasSuffix("v") || prefix.hasSuffix("-") {
                s = String(remainder)
            }
        }
        return s
    }
}

enum VersionComparator {
    static func isNewer(_ remote: String, than local: String) -> Bool {
        guard let remoteVersion = SemanticVersion(string: remote),
              let localVersion = SemanticVersion(string: local)
        else { return false }
        return remoteVersion > localVersion
    }
}
