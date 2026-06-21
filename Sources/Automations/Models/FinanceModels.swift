import Foundation

struct FinanceConnectionStatus: Decodable {
    let connected: Bool
    let institutionName: String?
    let itemId: String?
    let lastSyncedAt: String?
}

struct LinkTokenResponse: Decodable {
    // Keys map via the client's .convertFromSnakeCase strategy
    // (link_token → linkToken, hosted_link_url → hostedLinkUrl).
    // Do NOT add explicit snake_case CodingKeys: the strategy renames the JSON
    // keys first, so snake_case CodingKeys would never match → "data missing".
    let linkToken: String
    let hostedLinkUrl: String
    let expiration: String?
}

struct LinkCompleteResponse: Decodable {
    let connected: Bool
    let institutionName: String?
    let itemId: String?
}

struct LinkWaitResponse: Decodable {
    let ready: Bool
    let linkToken: String?
}

/// A parsed outflow/inflow before categorization. `signedAmount` < 0 = money out.
/// Kept in the store so transactions can be re-categorized (e.g. by AI) without re-importing.
struct RawTransaction: Codable, Sendable {
    let date: String      // normalized yyyy-MM-dd
    let name: String
    let signedAmount: Double

    /// Cache/lookup key — normalized merchant text.
    var key: String { Self.merchantKey(for: name) }

    /// Normalizes a description into the merchant key used for dedup + category memory.
    static func merchantKey(for name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

struct SpendingCategory: Codable, Identifiable {
    let category: String
    let total: Double
    let count: Int

    var id: String { category }
}

struct BankTransaction: Codable, Identifiable {
    let id: String
    let date: String
    let name: String
    let amount: Double
    let category: String
    let pending: Bool
}

struct SpendingSnapshot: Codable {
    let totalSpending: Double
    let transactionCount: Int
    let categories: [SpendingCategory]
    let recent: [BankTransaction]
    let syncedAt: String
}

/// Metadata about the most recent file import, shown in the dashboard header.
struct ImportSummary: Codable {
    let fileName: String
    let importedAt: Date
    let transactionCount: Int
    let earliestDate: String?
    let latestDate: String?
}

struct FinanceAPIErrorResponse: Decodable {
    let error: String
    let message: String?
}

enum FinanceAPIError: LocalizedError {
    case invalidURL
    case badStatus(Int, String?)
    case notConnected
    case linkCancelled
    case backendUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL."
        case .badStatus(let code, let message):
            message ?? "Request failed (\(code))."
        case .notConnected:
            "Connect your Wells Fargo account first."
        case .linkCancelled:
            "Bank connection was cancelled."
        case .backendUnavailable:
            "Finance API is not running. Start it with: cd backend && npm install && npm start"
        }
    }
}
