import SwiftUI

/// Shows a single automation running and its result. Owns the run lifecycle.
struct OutputView: View {
    let automation: Automation
    let onBack: () -> Void

    enum RunState {
        case running
        case finished(CommandResult)
    }

    @State private var state: RunState = .running

    var body: some View {
        VStack(spacing: 0) {
            HeroStripe()
            header
            Divider().overlay(Theme.hairline)
            output
            footer
        }
        .background(Theme.canvas)
        .task(id: automation.id) {
            state = .running
            let result = await CommandRunner.run(automation.command)
            state = .finished(result)
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Space.md) {
            IconTile(symbol: automation.symbol, accent: automation.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(automation.title)
                    .font(.inter(14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                Text(automation.command)
                    .font(.mono(12))
                    .foregroundStyle(Theme.mute)
            }
            Spacer()
            statusBadge
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 60)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .running:
            HStack(spacing: Theme.Space.xs) {
                ProgressView().controlSize(.small)
                Text("Running").font(.inter(12)).foregroundStyle(Theme.mute)
            }
        case .finished(let result):
            let color = result.succeeded ? Theme.accentGreen : Theme.accentRed
            Text(result.succeeded ? "Exit 0" : "Exit \(result.exitCode)")
                .font(.inter(12, weight: .medium))
                .foregroundStyle(color)
                .padding(.horizontal, Theme.Space.sm)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(color.opacity(0.15))
                )
        }
    }

    private var output: some View {
        ScrollView {
            Group {
                switch state {
                case .running:
                    Text("…")
                        .font(.mono(13))
                        .foregroundStyle(Theme.ash)
                case .finished(let result):
                    Text(result.output.isEmpty ? "(no output)" : result.output)
                        .font(.mono(13))
                        .foregroundStyle(result.output.isEmpty ? Theme.ash : Theme.body)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.surface)
    }

    private var footer: some View {
        HStack(spacing: Theme.Space.sm) {
            Button(action: onBack) {
                HStack(spacing: Theme.Space.xs) {
                    Image(systemName: "chevron.left").font(.system(size: 11, weight: .semibold))
                    Text("Back").font(.inter(12, weight: .medium))
                }
                .foregroundStyle(Theme.body)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            Spacer()
            Text("Back to palette").font(.inter(12)).foregroundStyle(Theme.mute)
            Keycap(label: "esc")
        }
        .padding(.horizontal, Theme.Space.lg)
        .frame(height: 38)
        .background(Theme.surface)
        .overlay(Divider().overlay(Theme.hairline), alignment: .top)
    }
}
