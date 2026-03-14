import Foundation

/// Shared markdown content processor that standardizes rendering across all views.
/// Strips YAML frontmatter, converts checkboxes to Unicode, and converts wikilinks to markdown links.
enum MarkdownProcessor {
    /// Process content through all transformations before rendering
    static func process(_ content: String) -> String {
        var result = content
        result = stripFrontmatter(result)
        result = renderCheckboxes(result)
        result = convertWikilinks(result)
        return result
    }

    /// Strip YAML front matter block from the start of content
    private static func stripFrontmatter(_ content: String) -> String {
        guard let range = content.range(
            of: #"^---\n(?:[\s\S]*?\n)?---\n?"#,
            options: .regularExpression
        ) else {
            return content
        }
        return String(content[range.upperBound...])
    }

    /// Replace markdown checkbox syntax with Unicode ballot characters
    private static func renderCheckboxes(_ content: String) -> String {
        var result = content
        // Unchecked: - [ ] → - ☐ ((?m) enables multiline mode for ^ to match line starts)
        result = result.replacingOccurrences(
            of: #"(?m)^(\s*)- \[ \]"#,
            with: "$1- ☐",
            options: .regularExpression
        )
        // Checked: - [x] or - [X] → - ☑
        result = result.replacingOccurrences(
            of: #"(?m)^(\s*)- \[[xX]\]"#,
            with: "$1- ☑",
            options: .regularExpression
        )
        return result
    }

    /// Convert [[wikilinks]] to standard markdown links with pkm: scheme.
    /// Targets are percent-encoded so that the resulting string is a valid URL.
    private static func convertWikilinks(_ content: String) -> String {
        // First handle [[target|display]] form, then [[target]] form
        var result = replaceWikilinks(
            in: content,
            pattern: #"\[\[([^\]|]+)\|([^\]]+)\]\]"#,
            hasDisplayText: true
        )
        result = replaceWikilinks(
            in: result,
            pattern: #"\[\[([^\]]+)\]\]"#,
            hasDisplayText: false
        )
        return result
    }

    /// Replace wikilinks matched by the given pattern, percent-encoding the target for the pkm: URL.
    private static func replaceWikilinks(in content: String, pattern: String, hasDisplayText: Bool) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return content }
        let nsContent = content as NSString
        var result = ""
        var lastIndex = 0

        let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))
        for match in matches {
            let matchRange = match.range
            if matchRange.location > lastIndex {
                let prefixRange = NSRange(location: lastIndex, length: matchRange.location - lastIndex)
                result += nsContent.substring(with: prefixRange)
            }

            let target = nsContent.substring(with: match.range(at: 1))
            let encodedTarget = target.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? target
            let displayText = hasDisplayText ? nsContent.substring(with: match.range(at: 2)) : target

            result += "[\(displayText)](pkm:\(encodedTarget))"
            lastIndex = matchRange.location + matchRange.length
        }

        if lastIndex < nsContent.length {
            result += nsContent.substring(with: NSRange(location: lastIndex, length: nsContent.length - lastIndex))
        }
        return result
    }
}
