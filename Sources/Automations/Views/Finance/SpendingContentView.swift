import SwiftUI

struct SpendingContentView: View {
    let spending: SpendingSnapshot
    /// Called when the user reassigns a transaction's category (merchant name, new category).
    var onCorrect: (String, String) -> Void = { _, _ in }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                summaryCards
                categorySection
                recentSection
            }
            .padding(Theme.Space.lg)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: Theme.Space.md) {
            MetricCard(
                title: "Total going out",
                value: formatCurrency(spending.totalSpending),
                footnote: "\(spending.transactionCount) transactions in database"
            )
            MetricCard(
                title: "Categories",
                value: "\(spending.categories.count)",
                footnote: "AI-categorized"
            )
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionTitle("Spending by category")
            VStack(spacing: 2) {
                ForEach(spending.categories) { row in
                    CategoryRow(
                        name: row.category,
                        amount: row.total,
                        count: row.count,
                        share: row.total / max(spending.totalSpending, 0.01)
                    )
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            sectionTitle("Recent outflows")
            VStack(spacing: 2) {
                ForEach(spending.recent) { txn in
                    TransactionRow(transaction: txn, onCorrect: onCorrect)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.inter(12, weight: .medium))
            .foregroundStyle(Theme.ash)
            .padding(.top, Theme.Space.sm)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(.inter(12))
                .foregroundStyle(Theme.mute)
            Text(value)
                .font(.inter(28, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(footnote)
                .font(.inter(11))
                .foregroundStyle(Theme.ash)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}

private struct CategoryRow: View {
    let name: String
    let amount: Double
    let count: Int
    let share: Double
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.inter(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Theme.surfaceElevated)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(Theme.accentRed.opacity(0.85))
                                .frame(width: geo.size.width * share)
                        }
                }
                .frame(height: 4)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatCurrency(amount))
                    .font(.inter(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text("\(count) txns")
                    .font(.inter(11))
                    .foregroundStyle(Theme.ash)
            }
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(hovered ? Theme.surfaceCard : .clear)
        )
        .onHover { hovered = $0 }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

private struct TransactionRow: View {
    let transaction: BankTransaction
    var onCorrect: (String, String) -> Void = { _, _ in }
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: Theme.Space.sm) {
                    Text(transaction.date)
                        .font(.inter(11))
                        .foregroundStyle(Theme.ash)
                    categoryMenu
                    if transaction.pending {
                        Text("Pending")
                            .font(.inter(10, weight: .medium))
                            .foregroundStyle(Theme.accentYellow)
                    }
                }
            }
            Spacer()
            Text(formatCurrency(transaction.amount))
                .font(.inter(13, weight: .medium))
                .foregroundStyle(Theme.accentRed)
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(hovered ? Theme.surfaceCard : .clear)
        )
        .onHover { hovered = $0 }
    }

    /// Clickable category chip — reassigning it corrects every transaction from this
    /// merchant and teaches the learning table.
    private var categoryMenu: some View {
        Menu {
            ForEach(SpendingCategories.names, id: \.self) { name in
                Button {
                    if name != transaction.category { onCorrect(transaction.name, name) }
                } label: {
                    if name == transaction.category {
                        Label(name, systemImage: "checkmark")
                    } else {
                        Text(name)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Text(transaction.category)
                    .font(.inter(11))
                    .foregroundStyle(Theme.mute)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Theme.ash)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(hovered ? Theme.surfaceElevated : .clear)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}
