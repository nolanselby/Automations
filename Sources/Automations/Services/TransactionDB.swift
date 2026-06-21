import Foundation
import GRDB

/// Result of an import: how many new transactions were stored vs. skipped as duplicates.
struct ImportDelta: Sendable {
    let added: Int
    let skipped: Int
}

/// SQLite-backed transaction store (via GRDB).
///
/// Dedup: bank CSVs have no stable ID, so identity = (date, amount, merchantKey).
/// Multiple identical charges on a day are tracked with an `occurrence` index, and
/// the unique index `(date, amount, merchantKey, occurrence)` makes re-imports and
/// overlapping date ranges idempotent — only genuinely new rows get inserted.
///
/// Learning: `merchant_categories` remembers each merchant's category so re-imports
/// don't re-call the AI, and manual corrections (later) persist here.
struct TransactionDB: Sendable {
    private let dbQueue: DatabaseQueue

    /// Pass an explicit `path` for tests; production uses the Application Support location.
    init(path: String? = nil) throws {
        let dbPath: String
        if let path {
            dbPath = path
        } else {
            let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Automations", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            dbPath = dir.appendingPathComponent("grimygrills.sqlite").path
        }
        dbQueue = try DatabaseQueue(path: dbPath)
        try Self.migrator.migrate(dbQueue)
    }

    private static var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "transactions") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("date", .text).notNull()
                t.column("amount", .double).notNull()
                t.column("description", .text).notNull()
                t.column("merchantKey", .text).notNull()
                t.column("occurrence", .integer).notNull()
                t.column("category", .text).notNull()
                t.column("sourceFile", .text)
                t.column("importedAt", .text).notNull()
                t.uniqueKey(["date", "amount", "merchantKey", "occurrence"])
            }
            try db.create(table: "merchant_categories") { t in
                t.primaryKey("merchantKey", .text)
                t.column("category", .text).notNull()
                t.column("source", .text).notNull()
                t.column("updatedAt", .text).notNull()
            }
        }
        return m
    }

    private static func now() -> String { ISO8601DateFormatter().string(from: Date()) }

    // MARK: - Import (dedup by multiplicity)

    func importTransactions(_ txns: [RawTransaction], sourceFile: String) throws -> ImportDelta {
        let importedAt = Self.now()

        struct GroupKey: Hashable { let date: String; let amount: Double; let key: String }
        var counts: [GroupKey: Int] = [:]
        var nameFor: [GroupKey: String] = [:]
        for t in txns {
            let g = GroupKey(date: t.date, amount: t.signedAmount, key: t.key)
            counts[g, default: 0] += 1
            if nameFor[g] == nil { nameFor[g] = t.name }
        }

        var added = 0
        try dbQueue.write { db in
            for (g, incoming) in counts {
                let existing = try Int.fetchOne(
                    db,
                    sql: "SELECT COUNT(*) FROM transactions WHERE date = ? AND amount = ? AND merchantKey = ?",
                    arguments: [g.date, g.amount, g.key]
                ) ?? 0
                guard incoming > existing else { continue }

                let name = nameFor[g] ?? ""
                let known = try String.fetchOne(
                    db,
                    sql: "SELECT category FROM merchant_categories WHERE merchantKey = ?",
                    arguments: [g.key]
                )
                let category = known ?? SpendingCategorizer.category(for: name)

                for occ in existing..<incoming {
                    try db.execute(
                        sql: """
                        INSERT INTO transactions
                            (date, amount, description, merchantKey, occurrence, category, sourceFile, importedAt)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                        arguments: [g.date, g.amount, name, g.key, occ, category, sourceFile, importedAt]
                    )
                    added += 1
                }
            }
        }
        return ImportDelta(added: added, skipped: txns.count - added)
    }

    // MARK: - Learning

    /// One representative transaction per merchant that has no remembered category yet.
    func merchantsNeedingCategory() throws -> [RawTransaction] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT t.description AS name, MAX(t.date) AS date, MIN(t.amount) AS amount
                FROM transactions t
                LEFT JOIN merchant_categories m ON m.merchantKey = t.merchantKey
                WHERE m.merchantKey IS NULL
                GROUP BY t.merchantKey
                """)
            return rows.map { row in
                let name: String = row["name"]
                let date: String = row["date"]
                let amount: Double = row["amount"]
                return RawTransaction(date: date, name: name, signedAmount: amount)
            }
        }
    }

    /// Persist merchant → category and update every matching transaction.
    func applyCategories(_ map: [String: String], source: String) throws {
        let now = Self.now()
        try dbQueue.write { db in
            for (key, category) in map {
                try db.execute(
                    sql: """
                    INSERT INTO merchant_categories (merchantKey, category, source, updatedAt)
                    VALUES (?, ?, ?, ?)
                    ON CONFLICT(merchantKey) DO UPDATE SET
                        category = excluded.category, source = excluded.source, updatedAt = excluded.updatedAt
                    """,
                    arguments: [key, category, source, now]
                )
                try db.execute(
                    sql: "UPDATE transactions SET category = ? WHERE merchantKey = ?",
                    arguments: [category, key]
                )
            }
        }
    }

    // MARK: - Read models

    func buildSnapshot() throws -> SpendingSnapshot {
        try dbQueue.read { db in
            let total = try Double.fetchOne(db, sql: "SELECT COALESCE(-SUM(amount), 0) FROM transactions WHERE amount < 0") ?? 0
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transactions WHERE amount < 0") ?? 0

            let categories: [SpendingCategory] = try Row.fetchAll(db, sql: """
                SELECT category AS c, -SUM(amount) AS total, COUNT(*) AS n
                FROM transactions WHERE amount < 0
                GROUP BY category ORDER BY total DESC
                """).map { row in
                let c: String? = row["c"]
                let totalOut: Double = row["total"]
                let n: Int = row["n"]
                return SpendingCategory(category: c ?? SpendingCategories.uncategorized, total: totalOut, count: n)
            }

            let recent: [BankTransaction] = try Row.fetchAll(db, sql: """
                SELECT id, date, description, amount, category
                FROM transactions WHERE amount < 0
                ORDER BY date DESC, id DESC LIMIT 50
                """).map { row in
                let id: Int64 = row["id"]
                let date: String = row["date"]
                let name: String = row["description"]
                let amount: Double = row["amount"]
                let category: String? = row["category"]
                return BankTransaction(
                    id: String(id), date: date, name: name, amount: -amount,
                    category: category ?? SpendingCategories.uncategorized, pending: false
                )
            }

            return SpendingSnapshot(
                totalSpending: total, transactionCount: count,
                categories: categories, recent: recent, syncedAt: Self.now()
            )
        }
    }

    /// Summary of everything stored, or nil if there are no outflows.
    func buildSummary(lastFile: String?) throws -> ImportSummary? {
        try dbQueue.read { db in
            let count = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM transactions WHERE amount < 0") ?? 0
            guard count > 0 else { return nil }
            let earliest = try String.fetchOne(db, sql: "SELECT MIN(date) FROM transactions")
            let latest = try String.fetchOne(db, sql: "SELECT MAX(date) FROM transactions")
            let file: String?
            if let lastFile {
                file = lastFile
            } else {
                file = try String.fetchOne(
                    db, sql: "SELECT sourceFile FROM transactions ORDER BY importedAt DESC, id DESC LIMIT 1")
            }
            return ImportSummary(
                fileName: file ?? "imported", importedAt: Date(),
                transactionCount: count, earliestDate: earliest, latestDate: latest
            )
        }
    }

    /// Clears stored transactions but keeps learned merchant categories.
    func clearTransactions() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM transactions")
        }
    }
}
