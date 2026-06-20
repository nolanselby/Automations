import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case finance = "Grimy Grills"
    case automations = "Automations"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .finance: "chart.bar.doc.horizontal"
        case .automations: "bolt.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .finance: "Spending & company numbers"
        case .automations: "Command palette"
        }
    }
}
