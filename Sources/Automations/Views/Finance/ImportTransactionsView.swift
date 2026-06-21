import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Shared file picker used by both the empty state and the dashboard header.
@MainActor
enum FinanceImport {
    static func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a Wells Fargo CSV export"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, .text]
        return panel.runModal() == .OK ? panel.url : nil
    }
}

/// Empty state: import a bank-export file via picker or drag-and-drop.
struct ImportTransactionsView: View {
    @Bindable var store: FinanceStore
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            IconTile(symbol: "tray.and.arrow.down.fill", accent: Theme.accentGreen)
                .scaleEffect(1.8)
                .padding(.bottom, Theme.Space.sm)

            Text("Import Wells Fargo transactions")
                .font(.inter(22, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Download your account activity from Wells Fargo online banking as a Comma-Delimited (CSV) file, then drop it below or choose it. Totals and categories populate instantly — no bank login is ever shared.")
                .font(.inter(14))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)

            downloadHint

            if let error = store.errorMessage {
                Text(error)
                    .font(.inter(13))
                    .foregroundStyle(Theme.accentRed)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            Button(action: choose) {
                HStack(spacing: Theme.Space.sm) {
                    if store.isImporting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "folder")
                    }
                    Text(store.isImporting ? "Importing…" : "Choose CSV file…")
                        .font(.inter(14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0x07080A))
                .padding(.horizontal, Theme.Space.xl)
                .padding(.vertical, Theme.Space.md)
                .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
            .disabled(store.isImporting)

            Text("…or drag a .csv file anywhere onto this panel")
                .font(.inter(12))
                .foregroundStyle(Theme.ash)

            Spacer()
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(
                    dropTargeted ? Theme.accentGreen : .clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .padding(Theme.Space.lg)
        )
        .onDrop(of: [.fileURL], isTargeted: $dropTargeted, perform: handleDrop)
    }

    private var downloadHint: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("Where to get the file")
                .font(.inter(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Wells Fargo online banking → your account → Download Account Activity → File Format: Comma Delimited (CSV) → pick a date range → Download.")
                .font(.inter(12))
                .foregroundStyle(Theme.body)
        }
        .padding(Theme.Space.md)
        .frame(maxWidth: 460, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(Theme.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private func choose() {
        guard let url = FinanceImport.pickFile() else { return }
        Task { await store.importFile(url: url) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in await store.importFile(url: url) }
        }
        return true
    }
}
