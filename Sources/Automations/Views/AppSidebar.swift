import SwiftUI

/// Clickable sidebar to switch between Grimy Grills finance and Automations.
struct AppSidebar: View {
    @Binding var selection: AppSection

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Automations")
                .font(.inter(11, weight: .medium))
                .foregroundStyle(Theme.ash)
                .padding(.horizontal, Theme.Space.md)
                .padding(.top, Theme.Space.lg)

            ForEach(AppSection.allCases) { section in
                SidebarRow(section: section, isActive: selection == section)
                    .contentShape(Rectangle())
                    .onTapGesture { selection = section }
            }

            Spacer()
        }
        .frame(width: 196)
        .background(Theme.surface)
        .overlay(
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

private struct SidebarRow: View {
    let section: AppSection
    let isActive: Bool
    @State private var hovered = false

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: section.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isActive ? Theme.accentGreen : Theme.mute)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(section.rawValue)
                    .font(.inter(13, weight: .medium))
                    .foregroundStyle(isActive ? Theme.ink : Theme.body)
                Text(section.subtitle)
                    .font(.inter(11))
                    .foregroundStyle(Theme.ash)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.Space.md)
        .padding(.vertical, Theme.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(isActive ? Theme.surfaceCard : (hovered ? Theme.surfaceElevated : .clear))
        )
        .padding(.horizontal, Theme.Space.sm)
        .onHover { hovered = $0 }
    }
}
