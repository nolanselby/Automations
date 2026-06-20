import Foundation

/// Accepts the local self-signed cert used for Plaid OAuth redirect testing.
private final class LocalHTTPSDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let shared = LocalHTTPSDelegate()

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host
        guard host == "localhost" || host == "127.0.0.1",
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

/// Talks to the local Plaid proxy (`backend/server.js`).
@MainActor
final class FinanceAPIClient {
    static let shared = FinanceAPIClient()

    var baseURL = URL(string: "https://localhost:8787")!

    private let session: URLSession = {
        URLSession(configuration: .default, delegate: LocalHTTPSDelegate.shared, delegateQueue: nil)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {}

    func health() async throws -> Bool {
        let url = baseURL.appending(path: "api/health")
        let (data, response) = try await session.data(from: url)
        try validate(response)
        struct Health: Decodable { let ok: Bool; let plaidConfigured: Bool }
        let health = try decoder.decode(Health.self, from: data)
        return health.ok
    }

    func connectionStatus() async throws -> FinanceConnectionStatus {
        try await get("api/status")
    }

    func createLinkToken() async throws -> LinkTokenResponse {
        try await post("api/link/token", body: EmptyBody())
    }

    func completeLink(linkToken: String) async throws -> LinkCompleteResponse {
        struct Body: Encodable { let linkToken: String }
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try await post("api/link/complete", body: Body(linkToken: linkToken), encoder: encoder)
    }

    func linkWait() async throws -> LinkWaitResponse {
        try await get("api/link/wait")
    }

    func disconnect() async throws {
        let _: EmptyResponse = try await post("api/disconnect", body: EmptyBody())
    }

    func fetchSpending() async throws -> SpendingSnapshot {
        try await get("api/spending")
    }

    // MARK: - HTTP helpers

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = baseURL.appending(path: path)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw FinanceAPIError.backendUnavailable
        }
        try validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable, B: Encodable>(
        _ path: String,
        body: B,
        encoder: JSONEncoder = JSONEncoder()
    ) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FinanceAPIError.backendUnavailable
        }
        try validate(response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            if let data,
               let apiError = try? decoder.decode(FinanceAPIErrorResponse.self, from: data) {
                if apiError.error == "not_connected" {
                    throw FinanceAPIError.notConnected
                }
                throw FinanceAPIError.badStatus(http.statusCode, apiError.message)
            }
            throw FinanceAPIError.badStatus(http.statusCode, nil)
        }
    }
}
