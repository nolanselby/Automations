import Foundation

enum AICategorizerError: LocalizedError {
    case missingKey
    case unauthorized
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            "No OpenAI API key found. Add it to ~/Library/Application Support/Automations/config.json."
        case .unauthorized:
            "OpenAI rejected the API key. Check it (or rotate it) and try again."
        case .badResponse(let detail):
            "OpenAI request failed: \(detail)"
        }
    }
}

/// Classifies transactions into the allowed Grimy Grills categories using OpenAI.
/// Provider-agnostic in spirit — only this file knows it's OpenAI.
struct AICategorizer {
    var model = "gpt-4o-mini"
    var batchSize = 40

    private struct ChatRequest: Encodable {
        let model: String
        let temperature: Double
        let response_format: ResponseFormat
        let messages: [Message]
        struct ResponseFormat: Encodable { let type = "json_object" }
        struct Message: Encodable { let role: String; let content: String }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]
        struct Choice: Decodable { let message: Message }
        struct Message: Decodable { let content: String }
    }

    private struct ResultPayload: Decodable {
        let results: [Item]
        struct Item: Decodable { let description: String; let category: String }
    }

    /// Returns a map of transaction `key` → category for the given transactions.
    /// Only unique descriptions are sent; the caller can cache the result.
    func classify(_ transactions: [RawTransaction], categories: [CostCategory]) async throws -> [String: String] {
        guard let apiKey = AppConfig.openAIKey else { throw AICategorizerError.missingKey }

        // One representative transaction per unique key keeps the request small.
        var representatives: [String: RawTransaction] = [:]
        for txn in transactions where representatives[txn.key] == nil {
            representatives[txn.key] = txn
        }
        let unique = Array(representatives.values)

        var mapping: [String: String] = [:]
        for batch in unique.chunked(into: batchSize) {
            let batchMap = try await classifyBatch(batch, categories: categories, apiKey: apiKey)
            mapping.merge(batchMap) { _, new in new }
        }
        return mapping
    }

    private func classifyBatch(
        _ batch: [RawTransaction],
        categories: [CostCategory],
        apiKey: String
    ) async throws -> [String: String] {
        let categoryLines = categories.filter(\.aiAssignable)
            .map { "- \($0.name): \($0.hint)" }
            .joined(separator: "\n")
        let system = """
        You categorize business bank transactions for "Grimy Grills", a grill-cleaning service.
        For each transaction, choose exactly one category from this list:
        \(categoryLines)
        Rules:
        - Payroll, wages, or employee compensation (e.g. Gusto, ADP, Paychex, "PAYROLL") must be "\(SpendingCategories.uncategorized)" — the bank feed cannot split labor by role. Never use a Labor category.
        - If none clearly fit, use "\(SpendingCategories.uncategorized)".
        Reply ONLY with JSON of the form:
        {"results":[{"description":"<verbatim description>","category":"<one category name>"}]}
        Use the exact category name (left of the colon). Preserve each description string exactly as given.
        """

        let items = batch.map { ["description": $0.name, "amount": String(format: "%.2f", -$0.signedAmount)] }
        let itemsJSON = String(data: try JSONSerialization.data(withJSONObject: items), encoding: .utf8) ?? "[]"
        let user = "Categorize these transactions (amount = dollars spent):\n\(itemsJSON)"

        let request = ChatRequest(
            model: model,
            temperature: 0,
            response_format: .init(),
            messages: [.init(role: "system", content: system), .init(role: "user", content: user)]
        )

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            if http.statusCode == 401 { throw AICategorizerError.unauthorized }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AICategorizerError.badResponse("HTTP \(http.statusCode) \(body.prefix(200))")
        }

        let chat = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content,
              let payloadData = content.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ResultPayload.self, from: payloadData)
        else { throw AICategorizerError.badResponse("Unexpected response format") }

        // Map each returned description back to the matching transaction key.
        var keyByName: [String: String] = [:]
        for txn in batch { keyByName[txn.name] = txn.key }

        var result: [String: String] = [:]
        for item in payload.results {
            let key = keyByName[item.description] ?? item.description.lowercased().trimmingCharacters(in: .whitespaces)
            result[key] = SpendingCategories.normalize(item.category)
        }
        return result
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
