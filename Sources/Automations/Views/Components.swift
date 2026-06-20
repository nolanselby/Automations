import SwiftUI

/// Small rounded icon tile that carries the one allowed splash of accent color.
struct IconTile: View {
    let symbol: String
    let accent: Color

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(accent.opacity(0.15))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(accent)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(accent.opacity(0.25), lineWidth: 1)
            )
            .frame(width: 30, height: 30)
    }
}

/// The signature Raycast launch-banner: three diagonal red stripes pinned to the top.
struct HeroStripe: View {
    var body: some View {
        Canvas { context, size in
            let stripeWidth = size.height * 0.9
            let gap = stripeWidth * 1.6
            var x = -size.height
            while x < size.width + size.height {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.addLine(to: CGPoint(x: x + size.height + stripeWidth, y: 0))
                path.addLine(to: CGPoint(x: x + stripeWidth, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xFF5757), Color(hex: 0xA1131A)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                ))
                x += gap
            }
        }
        .frame(height: 3)
    }
}

/// A keycap-style hint pill, e.g. ⏎ or ↵.
struct Keycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.inter(11, weight: .medium))
            .foregroundStyle(Theme.mute)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}
