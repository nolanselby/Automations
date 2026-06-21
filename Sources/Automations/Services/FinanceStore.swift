import Foundation
import Observation

@MainActor
@Observable
final class FinanceStore {
    var spending: SpendingSnapshot?
    var summary: ImportSummary?
    var isImporting = false
    var isCategorizing = false
    var errorMessage: String?
    /// Transient feedback after an import, e.g. "Added 42, skipped 12 duplicates".
    var lastImportMessage: String?

    var hasData: Bool { spending != nil }
    var hasAIKey: Bool { AppConfig.hasOpenAIKey }

    private let db: TransactionDB?

    init() {
        db = try? TransactionDB()
    }

    func loadPersisted() {
        refreshFromDB(lastFile: nil)
    }

    func importFile(url: URL) async {
        guard let db else { errorMessage = "Could not open the local database."; return }
        isImporting = true
        errorMessage = nil
        lastImportMessage = nil
        defer { isImporting = false }

        do {
            let parsed = try await Task.detached(priority: .userInitiated) {
                try TransactionImporter.parse(from: url)
            }.value
            let delta = try await Task.detached(priority: .userInitiated) {
                try db.importTransactions(parsed.transactions, sourceFile: parsed.fileName)
            }.value
            lastImportMessage = "Added \(delta.added), skipped \(delta.skipped) duplicate\(delta.skipped == 1 ? "" : "s")"
            refreshFromDB(lastFile: parsed.fileName)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        if hasAIKey { await categorizeWithAI() }
    }

    func categorizeWithAI() async {
        guard let db else { return }
        isCategorizing = true
        errorMessage = nil
        defer { isCategorizing = false }

        do {
            let pending = try await Task.detached(priority: .userInitiated) {
                try db.merchantsNeedingCategory()
            }.value
            guard !pending.isEmpty else { return }

            let map = try await AICategorizer().classify(pending, categories: SpendingCategories.all)
            try await Task.detached(priority: .userInitiated) {
                try db.applyCategories(map, source: "ai")
            }.value
            refreshFromDB(lastFile: summary?.fileName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Manual correction: set the category for a merchant and remember it (source = manual).
    /// Applies to every transaction from that merchant and persists to the learning table.
    func correctCategory(forMerchantNamed name: String, to category: String) async {
        guard let db else { return }
        let key = RawTransaction.merchantKey(for: name)
        do {
            try await Task.detached(priority: .userInitiated) {
                try db.applyCategories([key: category], source: "manual")
            }.value
            refreshFromDB(lastFile: summary?.fileName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        try? db?.clearTransactions()
        spending = nil
        summary = nil
        lastImportMessage = nil
        errorMessage = nil
    }

    private func refreshFromDB(lastFile: String?) {
        guard let db else { return }
        do {
            let summary = try db.buildSummary(lastFile: lastFile)
            self.summary = summary
            spending = summary == nil ? nil : try db.buildSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
