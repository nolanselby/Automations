import Foundation

/// Reads local app configuration (secrets, etc.).
///
/// The OpenAI key is read from, in order:
///   1. the `OPENAI_API_KEY` environment variable, or
///   2. `~/Library/Application Support/Automations/config.json` → `openai_api_key`.
///
/// The key is never stored in the repo or in source.
enum AppConfig {
    private struct ConfigFile: Decodable {
        let openai_api_key: String?
    }

    private static let configURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Automations", isDirectory: true)
            .appendingPathComponent("config.json")
    }()

    static var openAIKey: String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !env.trimmingCharacters(in: .whitespaces).isEmpty {
            return env
        }
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(ConfigFile.self, from: data),
              let key = config.openai_api_key?.trimmingCharacters(in: .whitespaces),
              !key.isEmpty
        else { return nil }
        return key
    }

    static var hasOpenAIKey: Bool { openAIKey != nil }
}
