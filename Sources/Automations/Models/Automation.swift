import SwiftUI

/// One runnable automation. The whole app's catalog is an array of these —
/// adding a new utility later is a single entry.
struct Automation: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    /// SF Symbol name shown in the row's icon tile.
    let symbol: String
    /// Accent color for the icon tile.
    let accent: Color
    /// The shell command, run via `/bin/zsh -lc`.
    let command: String

    static func == (lhs: Automation, rhs: Automation) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Automation {
    /// v1 catalog. One real command wired end-to-end; grow this list to add utilities.
    static let catalog: [Automation] = [
        Automation(
            title: "Who Am I",
            subtitle: "Print the current macOS user",
            symbol: "person.crop.circle",
            accent: Theme.accentGreen,
            command: "whoami"
        )
    ]
}
