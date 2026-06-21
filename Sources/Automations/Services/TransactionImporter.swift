import Foundation

struct ParsedImport: Sendable {
    let transactions: [RawTransaction]
    let fileName: String
    let earliestDate: String?
    let latestDate: String?
}

struct ImportResult: Sendable {
    let snapshot: SpendingSnapshot
    let summary: ImportSummary
}

enum ImportError: LocalizedError {
    case unreadable
    case noTransactions

    var errorDescription: String? {
        switch self {
        case .unreadable:
            "Couldn't read that file. Export your activity from Wells Fargo as a Comma-Delimited (CSV) file and try again."
        case .noTransactions:
            "No transactions found in that file. Make sure it's a Wells Fargo CSV with dates and amounts."
        }
    }
}

/// Parses a bank-export CSV into transactions, entirely on-device.
/// Handles Wells Fargo's header-less 5-column format and generic header CSVs.
enum TransactionImporter {
    static func parse(from url: URL) throws -> ParsedImport {
        guard let text = readText(url) else { throw ImportError.unreadable }
        let transactions = parseRows(text)
        guard !transactions.isEmpty else { throw ImportError.noTransactions }
        let dates = transactions.map(\.date).sorted()
        return ParsedImport(
            transactions: transactions,
            fileName: url.lastPathComponent,
            earliestDate: dates.first,
            latestDate: dates.last
        )
    }

    /// Builds a spending snapshot from parsed transactions using the supplied
    /// categorizer. Only outflows (money leaving the account) count as spending.
    static func snapshot(
        from parsed: ParsedImport,
        categorize: (RawTransaction) -> String
    ) -> ImportResult {
        let outflows = parsed.transactions.filter { $0.signedAmount < 0 }

        var categoryTotals: [String: (total: Double, count: Int)] = [:]
        for txn in outflows {
            let label = categorize(txn)
            let magnitude = -txn.signedAmount
            let existing = categoryTotals[label] ?? (0, 0)
            categoryTotals[label] = (existing.total + magnitude, existing.count + 1)
        }

        let categories = categoryTotals
            .map { SpendingCategory(category: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }

        let totalSpending = outflows.reduce(0) { $0 + (-$1.signedAmount) }

        let recent = outflows
            .sorted { $0.date > $1.date }
            .prefix(50)
            .map {
                BankTransaction(
                    id: UUID().uuidString,
                    date: $0.date,
                    name: $0.name,
                    amount: -$0.signedAmount,
                    category: categorize($0),
                    pending: false
                )
            }

        let snapshot = SpendingSnapshot(
            totalSpending: totalSpending,
            transactionCount: outflows.count,
            categories: categories,
            recent: Array(recent),
            syncedAt: ISO8601DateFormatter().string(from: Date())
        )
        let summary = ImportSummary(
            fileName: parsed.fileName,
            importedAt: Date(),
            transactionCount: outflows.count,
            earliestDate: parsed.earliestDate,
            latestDate: parsed.latestDate
        )
        return ImportResult(snapshot: snapshot, summary: summary)
    }

    // MARK: - File reading (try common bank-export encodings)

    private static func readText(_ url: URL) -> String? {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s }
        if let s = try? String(contentsOf: url, encoding: .windowsCP1252) { return s }
        if let s = try? String(contentsOf: url, encoding: .isoLatin1) { return s }
        return nil
    }

    // MARK: - Row parsing

    private static func parseRows(_ text: String) -> [RawTransaction] {
        let records = parseCSV(text).filter { !$0.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty } }
        guard !records.isEmpty else { return [] }

        let header = headerColumns(records[0])
        let dataRecords = header == nil ? records : Array(records.dropFirst())

        return dataRecords.compactMap { fields in
            guard fields.count >= 2 else { return nil }
            if let header {
                return row(from: fields, header: header)
            }
            // Wells Fargo header-less: date, amount, *, memo, description
            guard let amount = parseAmount(fields[1]),
                  let date = parseDate(fields[0]) else { return nil }
            let lastField = fields.last.map(cleaned) ?? ""
            let name = lastField.isEmpty
                ? (fields.count > 4 ? cleaned(fields[4]) : "Transaction")
                : lastField
            return RawTransaction(date: date, name: name.isEmpty ? "Transaction" : name, signedAmount: amount)
        }
    }

    /// If the first record looks like a header, return a column-name → index map.
    private static func headerColumns(_ fields: [String]) -> [String: Int]? {
        let lowered = fields.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        let looksLikeHeader = lowered.contains { f in
            ["date", "amount", "description", "debit", "credit", "payee", "memo"].contains { f.contains($0) }
        } && parseAmount(fields.count > 1 ? fields[1] : "") == nil
        guard looksLikeHeader else { return nil }
        var map: [String: Int] = [:]
        for (i, name) in lowered.enumerated() where map[name] == nil { map[name] = i }
        return map
    }

    private static func row(from fields: [String], header: [String: Int]) -> RawTransaction? {
        func value(_ predicate: (String) -> Bool) -> String? {
            for (name, idx) in header where predicate(name) && idx < fields.count { return fields[idx] }
            return nil
        }
        guard let rawDate = value({ $0.contains("date") }), let date = parseDate(rawDate) else { return nil }

        let name = cleaned(
            value({ $0.contains("description") || $0.contains("payee") || $0.contains("name") || $0.contains("memo") })
                ?? "Transaction"
        )

        let signed: Double
        if let amt = value({ $0.contains("amount") }), let v = parseAmount(amt) {
            signed = v
        } else {
            let debit = value({ $0.contains("debit") }).flatMap(parseAmount) ?? 0
            let credit = value({ $0.contains("credit") }).flatMap(parseAmount) ?? 0
            guard debit != 0 || credit != 0 else { return nil }
            signed = abs(credit) - abs(debit)  // credit in, debit out
        }
        return RawTransaction(date: date, name: name.isEmpty ? "Transaction" : name, signedAmount: signed)
    }

    // MARK: - Field helpers

    private static func cleaned(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func parseAmount(_ raw: String) -> Double? {
        var t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        var negative = false
        if t.hasPrefix("(") && t.hasSuffix(")") { negative = true; t = String(t.dropFirst().dropLast()) }
        t = t.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
        if t.hasPrefix("-") { negative = true; t = String(t.dropFirst()) }
        else if t.hasPrefix("+") { t = String(t.dropFirst()) }
        guard let v = Double(t) else { return nil }
        return negative ? -v : v
    }

    private static let dateFormatters: [DateFormatter] = {
        ["MM/dd/yyyy", "M/d/yyyy", "yyyy-MM-dd", "MM/dd/yy", "MM-dd-yyyy"].map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = fmt
            return f
        }
    }()

    private static let outputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Returns a normalized yyyy-MM-dd string, or nil if unparseable.
    private static func parseDate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        for f in dateFormatters {
            if let date = f.date(from: trimmed) { return outputFormatter.string(from: date) }
        }
        return nil
    }

    /// Minimal RFC-4180-ish CSV parser: handles quoted fields, escaped quotes, CRLF/LF.
    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0

        func endField() { record.append(field); field = "" }
        func endRecord() { endField(); rows.append(record); record = [] }

        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": endField()
                case "\r": break
                case "\n": endRecord()
                default: field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !record.isEmpty { endRecord() }
        return rows
    }
}
