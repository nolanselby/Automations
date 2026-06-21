import Foundation

/// A Grimy Grills cost category. `column` matches the spreadsheet header so the
/// data can map back to the sheet later; `name` is the display label; `hint`
/// guides the AI categorizer.
struct CostCategory: Identifiable, Sendable {
    let column: String   // e.g. "sale_labor_cost"
    let name: String     // e.g. "Sales Labor"
    let hint: String
    /// Whether the AI may assign this from bank data. The labor buckets are off:
    /// a payroll line can't be split into sales vs technician from the bank feed,
    /// so payroll goes to Misc until a payroll data source is connected.
    var aiAssignable: Bool = true
    var id: String { name }
}

/// The allowed cost categories. Edit this list to change the buckets.
/// (Mirrors the spreadsheet's `*_cost` columns; `total_cost` is a sum, not a bucket.)
enum SpendingCategories {
    /// Catch-all bucket — matches the sheet's `misc_cost`.
    static let uncategorized = "Misc"

    static let all: [CostCategory] = [
        CostCategory(column: "sale_labor_cost", name: "Sales Labor",
                     hint: "Payroll, wages, or commissions for sales staff.",
                     aiAssignable: false),
        CostCategory(column: "tech_labor_cost", name: "Technician Labor",
                     hint: "Payroll or wages for technicians who perform the grill-cleaning jobs.",
                     aiAssignable: false),
        CostCategory(column: "supply_cost", name: "Supplies",
                     hint: "Cleaning supplies, chemicals, parts, and consumables used on jobs (e.g. Home Depot, Uline, restaurant/janitorial suppliers)."),
        CostCategory(column: "fuel_cost", name: "Fuel",
                     hint: "Gas or fuel for vehicles (Shell, Chevron, Arco, etc.)."),
        CostCategory(column: "tech_cost", name: "Tech",
                     hint: "Software, apps, and SaaS subscriptions (e.g. Adobe, QuickBooks, Google Workspace, scheduling/CRM tools)."),
        CostCategory(column: "marketing_cost", name: "Marketing",
                     hint: "Advertising and marketing — Meta/Facebook, Google, Yelp, TikTok ads, flyers, etc."),
        CostCategory(column: "insurance_cost", name: "Insurance",
                     hint: "Business insurance premiums (liability, vehicle, workers' comp)."),
        CostCategory(column: "misc_cost", name: uncategorized,
                     hint: "Anything that does not clearly fit another category."),
    ]

    static var names: [String] { all.map(\.name) }

    /// Snaps an arbitrary label to a known category (case-insensitive), else Misc.
    static func normalize(_ label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return names.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame } ?? uncategorized
    }
}
