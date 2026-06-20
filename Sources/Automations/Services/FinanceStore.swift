import Foundation
import Observation

@MainActor
@Observable
final class FinanceStore {
    var connection: FinanceConnectionStatus?
    var spending: SpendingSnapshot?
    var isLoading = false
    var isConnecting = false
    var backendOnline = false
    var errorMessage: String?

    private let api = FinanceAPIClient.shared

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            backendOnline = try await api.health()
            connection = try await api.connectionStatus()
            if connection?.connected == true {
                spending = try await api.fetchSpending()
            } else {
                spending = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            if case FinanceAPIError.backendUnavailable = error {
                backendOnline = false
            }
        }
    }

    func connectWellsFargo() async {
        isConnecting = true
        errorMessage = nil
        defer { isConnecting = false }

        do {
            backendOnline = try await api.health()
            _ = try await PlaidLinkFlow.connect(api: api)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.disconnect()
            connection = FinanceConnectionStatus(connected: false, institutionName: nil, itemId: nil, lastSyncedAt: nil)
            spending = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
