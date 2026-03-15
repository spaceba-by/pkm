import Foundation

enum DiffError: LocalizedError {
    case processError(String)

    var errorDescription: String? {
        switch self {
        case let .processError(message):
            "diff failed: \(message)"
        }
    }
}

protocol DiffServiceProtocol: Sendable {
    func diff(originalPath: String, conflictPath: String) async throws -> [DiffLine]
}

struct DiffService: DiffServiceProtocol {
    func diff(originalPath: String, conflictPath: String) async throws -> [DiffLine] {
        let originalExists = FileManager.default.fileExists(atPath: originalPath)
        let conflictExists = FileManager.default.fileExists(atPath: conflictPath)

        guard originalExists || conflictExists else {
            return []
        }

        if !originalExists {
            return try readAllLines(path: conflictPath, type: .added)
        }

        if !conflictExists {
            return try readAllLines(path: originalPath, type: .removed)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/diff")
        process.arguments = ["-u", originalPath, conflictPath]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        // Read pipe data before waitUntilExit to avoid pipe buffer deadlock
        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        // diff exits 0 (identical), 1 (differences), 2 (error)
        if process.terminationStatus == 2 {
            let stderrMessage = String(data: stderrData, encoding: .utf8) ?? "Unknown error"
            throw DiffError.processError(stderrMessage.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let output = String(data: data, encoding: .utf8) ?? ""

        return parseDiffOutput(output)
    }

    private func readAllLines(path: String, type: DiffLineType) throws -> [DiffLine] {
        let content = try String(contentsOfFile: path, encoding: .utf8)
        return content.components(separatedBy: .newlines).enumerated().map { index, line in
            DiffLine(id: index, text: line, type: type)
        }
    }

    func parseDiffOutput(_ output: String) -> [DiffLine] {
        guard !output.isEmpty else { return [] }

        let lines = output.components(separatedBy: .newlines)
        var result: [DiffLine] = []

        for (index, line) in lines.enumerated() {
            // Skip the --- and +++ file headers
            if line.hasPrefix("---") || line.hasPrefix("+++") {
                continue
            }

            let type: DiffLineType =
                if line.hasPrefix("@@") {
                    .header
                } else if line.hasPrefix("+") {
                    .added
                } else if line.hasPrefix("-") {
                    .removed
                } else {
                    .context
                }

            let displayText: String =
                if type == .added || type == .removed {
                    String(line.dropFirst())
                } else {
                    line
                }

            result.append(DiffLine(id: index, text: displayText, type: type))
        }

        return result
    }
}
