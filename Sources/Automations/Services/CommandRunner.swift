import Foundation

/// The only code that touches the shell. Runs a command via `/bin/zsh -lc`
/// and returns combined output + exit code. Isolated so it can be tested alone.
struct CommandResult: Sendable {
    let output: String
    let exitCode: Int32
    var succeeded: Bool { exitCode == 0 }
}

enum CommandRunner {
    /// Runs `command` and returns its combined stdout/stderr and exit code.
    /// `-l` gives a login shell so the user's PATH and aliases are available.
    static func run(_ command: String) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-lc", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: CommandResult(
                        output: "Failed to launch command:\n\(error.localizedDescription)",
                        exitCode: -1
                    ))
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                let text = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: CommandResult(
                    output: text.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: process.terminationStatus
                ))
            }
        }
    }
}
