import SwiftUI

/// Raycast design tokens, transcribed from awesome-design-md/design-md/raycast.
/// Centralized so the whole app stays on one tonal palette.
enum Theme {
    // MARK: Surfaces
    static let canvas = Color(hex: 0x07080A)
    static let surface = Color(hex: 0x0D0D0D)
    static let surfaceElevated = Color(hex: 0x101111)
    static let surfaceCard = Color(hex: 0x121212)

    // MARK: Text
    static let ink = Color(hex: 0xF4F4F6)
    static let body = Color(hex: 0xCDCDCD)
    static let mute = Color(hex: 0x9C9C9D)
    static let ash = Color(hex: 0x6A6B6C)

    // MARK: Lines
    static let hairline = Color(hex: 0x242728)
    static let hairlineSoft = Color.white.opacity(0.08)
    static let hairlineStrong = Color.white.opacity(0.16)

    // MARK: Accents (reserved for automation icons / status)
    static let accentBlue = Color(hex: 0x57C1FF)
    static let accentRed = Color(hex: 0xFF6161)
    static let accentGreen = Color(hex: 0x59D499)
    static let accentYellow = Color(hex: 0xFFC533)

    // MARK: Hero stripe gradient
    static let heroStripe = LinearGradient(
        colors: [Color(hex: 0xFF5757), Color(hex: 0xA1131A)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Radii
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 16
    }

    // MARK: Spacing
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

/// Inter with the ss03 stylistic set if available, otherwise the system font.
/// Inter ships the design; the system font is a clean fallback when it isn't installed.
extension Font {
    static func inter(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.custom("Inter", size: size).weight(weight)
    }

    static func mono(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .regular, design: .monospaced)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
