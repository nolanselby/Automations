import SwiftUI

/// Grimy Grills company numbers — phase 1 focuses on bank spending.
struct FinanceDashboardView: View {
    @Bindable var store: FinanceStore

    var body: some View {
        VStack(spacing: 0) {
            HeroStripe()
            header
            Divider().overlay(Theme.hairline)

            if let spending = store.spending {
                SpendingContentView(spending: spending) { merchant, category in
                    Task { await store.correctCategory(forMerchantNamed: merchant, to: category) }
                }
            } else {
                ImportTransactionsView(store: store)
            }
        }
        .background(Theme.canvas)
        .onAppear { store.loadPersisted() }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grimy Grills")
                    .font(.inter(20, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.inter(13))
                    .foregroundStyle(Theme.mute)
                if let message = store.lastImportMessage {
                    Text(message)
                        .font(.inter(11, weight: .medium))
                        .foregroundStyle(Theme.accentGreen)
                }
            }
            Spacer()

            if store.hasData {
                if store.hasAIKey {
                    ActionButton(
                        title: store.isCategorizing ? "Categorizing…" : "Categorize with AI",
                        symbol: "sparkles",
                        isLoading: store.isCategorizing
                    ) {
                        Task { await store.categorizeWithAI() }
                    }
                }
                ActionButton(title: "Re-import", symbol: "arrow.clockwise", isLoading: store.isImporting) {
                    guard let url = FinanceImport.pickFile() else { return }
                    Task { await store.importFile(url: url) }
                }
                ActionButton(title: "Clear", symbol: "trash", destructive: true) {
                    store.clear()
                }
            }
        }
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
    }

    private var subtitle: String {
        guard let summary = store.summary else { return "Spending" }
        let range = [summary.earliestDate, summary.latestDate].compactMap { $0 }
        let span = range.count == 2 ? " · \(range[0]) → \(range[1])" : ""
        return "Spending · \(summary.transactionCount) transactions\(span)"
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
