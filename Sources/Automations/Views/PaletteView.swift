import SwiftUI

/// The Raycast-style command palette: search field on top, filtered rows below,
/// keyboard navigation (↑/↓ to move, ⏎ to run).
struct PaletteView: View {
    let automations: [Automation]
    /// Called when the user runs an automation (click or ⏎).
    let onRun: (Automation) -> Void

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var searchFocused: Bool

    private var filtered: [Automation] {
        guard !query.isEmpty else { return automations }
        return automations.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroStripe()
            searchBar
            Divider().overlay(Theme.hairline)
            resultsList
            footer
        }
        .background(Theme.canvas)
        .onAppear { searchFocused = true }
        .onChange(of: query) { _, _ in selection = 0 }
    }

    private var searchBar: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.ash)
            TextField("Search automations…", text: $query)
                .textFieldStyle(.plain)
                .font(.inter(18))
                .foregroundStyle(Theme.ink)
                .focused($searchFocused)
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
                .onKeyPress(.return) { runSelected(); return .handled }
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 52)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        sectionHeader("Automations")
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { index, automation in
                            AutomationRow(automation: automation, isActive: index == selection)
                                .id(index)
                                .contentShape(Rectangle())
                                .onTapGesture { onRun(automation) }
                                .onHover { if $0 { selection = index } }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, Theme.Space.sm)
            }
            .onChange(of: selection) { _, new in
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.inter(12, weight: .medium))
            .foregroundStyle(Theme.ash)
            .padding(.horizontal, Theme.Space.sm)
            .padding(.top, Theme.Space.xs)
            .padding(.bottom, Theme.Space.xs)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Space.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22))
                .foregroundStyle(Theme.ash)
            Text("No automations match “\(query)”")
                .font(.inter(14))
                .foregroundStyle(Theme.mute)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.sm) {
            Text("Automations")
                .font(.inter(12, weight: .medium))
                .foregroundStyle(Theme.mute)
            Spacer()
            Text("Run")
                .font(.inter(12))
                .foregroundStyle(Theme.mute)
            Keycap(label: "↵")
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 38)
        .background(Theme.surface)
        .overlay(Divider().overlay(Theme.hairline), alignment: .top)
    }

    private func move(_ delta: Int) {
        guard !filtered.isEmpty else { return }
        selection = min(max(selection + delta, 0), filtered.count - 1)
    }

    private func runSelected() {
        guard filtered.indices.contains(selection) else { return }
        onRun(filtered[selection])
    }
}

/// A single command-palette row.
private struct AutomationRow: View {
    let automation: Automation
    let isActive: Bool

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            IconTile(symbol: automation.symbol, accent: automation.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(automation.title)
                    .font(.inter(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(automation.subtitle)
                    .font(.inter(12))
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
            if isActive {
                Text("Run")
                    .font(.inter(12))
                    .foregroundStyle(Theme.mute)
                Keycap(label: "↵")
            }
        }
        .padding(.horizontal, Theme.Space.sm)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(isActive ? Theme.surfaceCard : .clear)
        )
    }
}
