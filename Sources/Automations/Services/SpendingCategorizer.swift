import Foundation

/// Keyword fallback categorization, used only when the AI categorizer is
/// unavailable (no API key / offline). Returns one of the Grimy Grills
/// categories defined in `SpendingCategories`.
enum SpendingCategorizer {
    /// Ordered keyword → category rules. First match wins.
    private static let rules: [(keywords: [String], category: String)] = [
        (["sysco", "us foods", "usfoods", "restaurant depot", "uline", "home depot",
          "lowe's", "lowes", "grainger", "chemical", "supply", "supplies"], "Supplies"),
        (["facebook", "meta platforms", "facebk", "instagram", "google ads", "google *ads",
          "adwords", "yelp", "tiktok", "snapchat", "marketing", "advert"], "Marketing"),
        (["shell", "chevron", "exxon", "arco", "76 ", "valero", "fuel", "gas station"], "Fuel"),
        (["adobe", "quickbooks", "intuit", "google workspace", "gsuite", "microsoft",
          "zoom", "slack", "godaddy", "squarespace", "saas", "software", "subscription",
          "jobber", "housecall", "servicetitan"], "Tech"),
        (["state farm", "geico", "insurance", "liberty mutual", "progressive", "hartford"], "Insurance"),
        // Payroll can't be split into sales vs technician labor from bank data → Misc.
        (["gusto", "adp", "paychek", "paychex", "payroll", "wages"], SpendingCategories.uncategorized),
    ]

    static func category(for description: String) -> String {
        let haystack = description.lowercased()
        for rule in rules where rule.keywords.contains(where: haystack.contains) {
            return rule.category
        }
        return SpendingCategories.uncategorized
    }
}
