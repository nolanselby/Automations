import Foundation

struct FinanceConnectionStatus: Decodable {
    let connected: Bool
    let institutionName: String?
    let itemId: String?
    let lastSyncedAt: String?
}

struct LinkTokenResponse: Decodable {
    let linkToken: String
    let hostedLinkURL: String
    let expiration: String?

    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
        case hostedLinkURL = "hosted_link_url"
        case expiration
    }
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

struct SpendingCategory: Decodable, Identifiable {
    let category: String
    let total: Double
    let count: Int

    var id: String { category }
}

struct BankTransaction: Decodable, Identifiable {
    let id: String
    let date: String
    let name: String
    let amount: Double
    let category: String
    let pending: Bool
}

struct SpendingSnapshot: Decodable {
    let totalSpending: Double
    let transactionCount: Int
    let categories: [SpendingCategory]
    let recent: [BankTransaction]
    let syncedAt: String
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
