import XCTest
@testable import Automations

final class DedupTests: XCTestCase {
    private func makeDB() throws -> TransactionDB {
        let path = NSTemporaryDirectory() + "grimy-test-\(UUID().uuidString).sqlite"
        return try TransactionDB(path: path)
    }

    private func txn(_ date: String, _ amount: Double, _ name: String) -> RawTransaction {
        RawTransaction(date: date, name: name, signedAmount: amount)
    }

    func testFreshImportAddsAll() throws {
        let db = try makeDB()
        let delta = try db.importTransactions([
            txn("2026-06-01", -10, "SHELL OIL"),
            txn("2026-06-02", -20, "HOME DEPOT"),
            txn("2026-06-03", -30, "JOBBER SOFTWARE"),
        ], sourceFile: "june.csv")
        XCTAssertEqual(delta.added, 3)
        XCTAssertEqual(delta.skipped, 0)
        XCTAssertEqual(try db.buildSnapshot().transactionCount, 3)
    }

    func testReimportingSameFileAddsNothing() throws {
        let db = try makeDB()
        let rows = [
            txn("2026-06-01", -10, "SHELL OIL"),
            txn("2026-06-02", -20, "HOME DEPOT"),
        ]
        _ = try db.importTransactions(rows, sourceFile: "june.csv")
        let second = try db.importTransactions(rows, sourceFile: "june.csv")
        XCTAssertEqual(second.added, 0)
        XCTAssertEqual(second.skipped, 2)
        XCTAssertEqual(try db.buildSnapshot().transactionCount, 2)
    }

    func testOverlappingRangeAddsOnlyNew() throws {
        let db = try makeDB()
        _ = try db.importTransactions([
            txn("2026-06-01", -10, "SHELL OIL"),
            txn("2026-06-02", -20, "HOME DEPOT"),
        ], sourceFile: "early.csv")
        let overlap = try db.importTransactions([
            txn("2026-06-02", -20, "HOME DEPOT"),   // duplicate
            txn("2026-06-03", -30, "JOBBER SOFTWARE"), // new
        ], sourceFile: "late.csv")
        XCTAssertEqual(overlap.added, 1)
        XCTAssertEqual(overlap.skipped, 1)
        XCTAssertEqual(try db.buildSnapshot().transactionCount, 3)
    }

    func testLegitimateSameDayDuplicatesKept() throws {
        let db = try makeDB()
        // Two genuinely identical $4.50 coffees on the same day.
        let delta = try db.importTransactions([
            txn("2026-06-01", -4.50, "COFFEE SHOP"),
            txn("2026-06-01", -4.50, "COFFEE SHOP"),
        ], sourceFile: "june.csv")
        XCTAssertEqual(delta.added, 2)
        // Re-importing the same two must not add more.
        let again = try db.importTransactions([
            txn("2026-06-01", -4.50, "COFFEE SHOP"),
            txn("2026-06-01", -4.50, "COFFEE SHOP"),
        ], sourceFile: "june.csv")
        XCTAssertEqual(again.added, 0)
        XCTAssertEqual(try db.buildSnapshot().transactionCount, 2)
    }

    func testTotalsAndDepositsExcluded() throws {
        let db = try makeDB()
        _ = try db.importTransactions([
            txn("2026-06-01", -10, "SHELL OIL"),
            txn("2026-06-02", -15, "HOME DEPOT"),
            txn("2026-06-03", 500, "CUSTOMER DEPOSIT"), // inflow — excluded from spending
        ], sourceFile: "june.csv")
        let snap = try db.buildSnapshot()
        XCTAssertEqual(snap.transactionCount, 2)
        XCTAssertEqual(snap.totalSpending, 25, accuracy: 0.001)
    }

    func testManualCorrectionMovesAllMerchantTxnsAndPersists() throws {
        let db = try makeDB()
        // Two charges from the same merchant, initially keyword-categorized.
        _ = try db.importTransactions([
            txn("2026-06-01", -10, "ACME WIDGETS"),
            txn("2026-06-05", -25, "ACME WIDGETS"),
        ], sourceFile: "june.csv")

        // User corrects the merchant to "Supplies".
        try db.applyCategories([RawTransaction.merchantKey(for: "ACME WIDGETS"): "Supplies"], source: "manual")

        let snap = try db.buildSnapshot()
        let supplies = snap.categories.first { $0.category == "Supplies" }
        XCTAssertEqual(supplies?.count, 2)
        XCTAssertEqual(supplies?.total ?? 0, 35, accuracy: 0.001)

        // The correction is remembered: a later import of the same merchant inherits it.
        _ = try db.importTransactions([txn("2026-07-02", -5, "ACME WIDGETS")], sourceFile: "july.csv")
        let after = try db.buildSnapshot().categories.first { $0.category == "Supplies" }
        XCTAssertEqual(after?.count, 3)
    }

    func testLearnedCategoryAppliesToFutureImports() throws {
        let db = try makeDB()
        _ = try db.importTransactions([txn("2026-06-01", -10, "MYSTERY VENDOR LLC")], sourceFile: "a.csv")
        try db.applyCategories(["mystery vendor llc": "Supplies"], source: "manual")
        // A later import of the same merchant should inherit the learned category.
        _ = try db.importTransactions([txn("2026-07-01", -12, "MYSTERY VENDOR LLC")], sourceFile: "b.csv")
        let snap = try db.buildSnapshot()
        let supplies = snap.categories.first { $0.category == "Supplies" }
        XCTAssertEqual(supplies?.count, 2)
        XCTAssertEqual(supplies?.total ?? 0, 22, accuracy: 0.001)
    }
}
