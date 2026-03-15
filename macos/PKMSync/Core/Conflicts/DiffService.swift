import Foundation

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

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
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

            let type: DiffLineType
            if line.hasPrefix("@@") {
                type = .header
            } else if line.hasPrefix("+") {
                type = .added
            } else if line.hasPrefix("-") {
                type = .removed
            } else {
                type = .context
            }

            let displayText: String
            if type == .added || type == .removed {
                displayText = String(line.dropFirst())
            } else {
                displayText = line
            }

            result.append(DiffLine(id: index, text: displayText, type: type))
        }

        return result
    }
}
