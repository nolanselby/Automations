import SwiftUI

/// Grimy Grills company numbers — phase 1 focuses on bank spending.
struct FinanceDashboardView: View {
    @Bindable var store: FinanceStore

    var body: some View {
        VStack(spacing: 0) {
            HeroStripe()
            header
            Divider().overlay(Theme.hairline)

            if store.connection?.connected == true, let spending = store.spending {
                SpendingContentView(spending: spending)
            } else {
                ConnectBankView(store: store)
            }
        }
        .background(Theme.canvas)
        .task { await store.refresh() }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grimy Grills")
                    .font(.inter(20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text("Spending")
                    .font(.inter(13))
                    .foregroundStyle(Theme.mute)
            }
            Spacer()

            if store.connection?.connected == true {
                if let name = store.connection?.institutionName {
                    Text(name)
                        .font(.inter(12))
                        .foregroundStyle(Theme.mute)
                }
                ActionButton(title: "Refresh", symbol: "arrow.clockwise", isLoading: store.isLoading) {
                    Task { await store.refresh() }
                }
                ActionButton(title: "Disconnect", symbol: "link.badge.minus", destructive: true) {
                    Task { await store.disconnect() }
                }
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
    }
}

private struct ActionButton: View {
    let title: String
    let symbol: String
    var isLoading = false
    var destructive = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(.inter(12, weight: .medium))
            }
            .foregroundStyle(destructive ? Theme.accentRed : Theme.ink)
            .padding(.horizontal, Theme.Space.md)
            .padding(.vertical, Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(hovered ? Theme.surfaceCard : Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .onHover { hovered = $0 }
    }
}
