import SwiftUI

struct ConnectBankView: View {
    @Bindable var store: FinanceStore

    var body: some View {
        VStack(spacing: Theme.Space.xl) {
            Spacer()

            IconTile(symbol: "building.columns.fill", accent: Theme.accentYellow)
                .scaleEffect(1.8)
                .padding(.bottom, Theme.Space.sm)

            Text("Connect Wells Fargo")
                .font(.inter(22, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("Link your business checking account to pull up-to-date transactions. Spending totals and categories will populate here once connected.")
                .font(.inter(14))
                .foregroundStyle(Theme.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if !store.backendOnline {
                setupCallout
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.inter(13))
                    .foregroundStyle(Theme.accentRed)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            Button {
                Task { await store.connectWellsFargo() }
            } label: {
                HStack(spacing: Theme.Space.sm) {
                    if store.isConnecting {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "link")
                    }
                    Text(store.isConnecting ? "Waiting for sign-in…" : "Connect bank account")
                        .font(.inter(14, weight: .semibold))
                }
                .foregroundStyle(Color(hex: 0x07080A))
                .padding(.horizontal, Theme.Space.xl)
                .padding(.vertical, Theme.Space.md)
                .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(.plain)
            .disabled(store.isConnecting || !store.backendOnline)

            Button("Refresh status") {
                Task { await store.refresh() }
            }
            .buttonStyle(.plain)
            .font(.inter(12))
            .foregroundStyle(Theme.mute)

            Spacer()
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var setupCallout: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text("One-time setup")
                .font(.inter(13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("1. Run Scripts/setup-local-https.sh\n2. Copy backend/.env.example → backend/.env\n3. Add Plaid keys + set redirect URIs in dashboard\n4. Run: cd backend && npm install && npm start")
                .font(.mono(12))
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
}
