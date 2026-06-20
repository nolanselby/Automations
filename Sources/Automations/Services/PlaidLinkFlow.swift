import AppKit

/// Opens Plaid Hosted Link in the default browser, then polls the local API for completion.
@MainActor
enum PlaidLinkFlow {
    static func connect(api: FinanceAPIClient = .shared) async throws -> LinkCompleteResponse {
        let token = try await api.createLinkToken()
        guard let url = URL(string: token.hostedLinkURL) else {
            throw FinanceAPIError.invalidURL
        }

        NSWorkspace.shared.open(url)

        let linkToken = token.linkToken
        for _ in 0..<120 {
            try await Task.sleep(for: .seconds(1))
            let wait: LinkWaitResponse = try await api.linkWait()
            if wait.ready, wait.linkToken != nil {
                return try await api.completeLink(linkToken: linkToken)
            }
        }

        throw FinanceAPIError.badStatus(408, "Timed out waiting for bank sign-in. Finish in the browser and tap Refresh.")
    }
}
