import SwiftUI
import Foundation

struct ThemeGlow {
    let darkHex: UInt
    let lightHex: UInt
    let darkAlpha: Double
    let lightAlpha: Double
}

struct AppThemePalette {
    let brandA: UInt
    let brandB: UInt
    let brandC: UInt
    let accent: UInt
    let brandMidA: UInt
    let brandMidB: UInt

    let backdropDark: UInt
    let backdropLight: UInt
    let bgDarkStops: [UInt]
    let bgLightStops: [UInt]

    let glowA: ThemeGlow
    let glowB: ThemeGlow
    let glowC: ThemeGlow
}

enum AppTheme: String, CaseIterable, Identifiable {
    case aurora
    case goldenHour
    case graphite
    case seaBreeze

    static let storageKey = "app.theme"
    static let defaultTheme: AppTheme = .aurora

    var id: String { rawValue }

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        return AppTheme(rawValue: raw ?? "") ?? defaultTheme
    }

    func name(lang: AppLang) -> String {
        switch (self, lang) {
        case (.aurora, .ru): return "Северное сияние"
        case (.goldenHour, .ru): return "Золотой час"
        case (.graphite, .ru): return "Графитовый люкс"
        case (.seaBreeze, .ru): return "Лазурный бриз"

        case (.aurora, .en): return "Northern Lights"
        case (.goldenHour, .en): return "Golden Hour"
        case (.graphite, .en): return "Graphite Luxe"
        case (.seaBreeze, .en): return "Azure Breeze"

        case (.aurora, .de): return "Nordlicht"
        case (.goldenHour, .de): return "Goldene Stunde"
        case (.graphite, .de): return "Graphit Luxus"
        case (.seaBreeze, .de): return "Azur Brise"

        case (.aurora, .es): return "Aurora Boreal"
        case (.goldenHour, .es): return "Hora Dorada"
        case (.graphite, .es): return "Lujo Grafito"
        case (.seaBreeze, .es): return "Brisa Azul"
        }
    }

    func subtitle(lang: AppLang) -> String {
        switch (self, lang) {
        case (.aurora, .ru): return "Холодный неон и стекло"
        case (.goldenHour, .ru): return "Тёплый свет заката"
        case (.graphite, .ru): return "Строгий монохром"
        case (.seaBreeze, .ru): return "Свежий морской тон"

        case (.aurora, .en): return "Cold neon and glass"
        case (.goldenHour, .en): return "Warm sunset glow"
        case (.graphite, .en): return "Strict monochrome"
        case (.seaBreeze, .en): return "Fresh sea tone"

        case (.aurora, .de): return "Kaltes Neon und Glas"
        case (.goldenHour, .de): return "Warmes Abendlicht"
        case (.graphite, .de): return "Strenger Monochrom-Look"
        case (.seaBreeze, .de): return "Frischer Meeres-Ton"

        case (.aurora, .es): return "Neón frío y cristal"
        case (.goldenHour, .es): return "Brillo cálido del atardecer"
        case (.graphite, .es): return "Monocromo elegante"
        case (.seaBreeze, .es): return "Tono marino fresco"
        }
    }

    var palette: AppThemePalette {
        switch self {
        case .aurora:
            return AppThemePalette(
                brandA: 0x0A84FF,
                brandB: 0x5AC8FA,
                brandC: 0x30D158,
                accent: 0x0A84FF,
                brandMidA: 0x2E92FF,
                brandMidB: 0x46B4FF,
                backdropDark: 0x111214,
                backdropLight: 0xF6F9FF,
                bgDarkStops: [0x101114, 0x13151A, 0x191C22, 0x14171D, 0x0F1013],
                bgLightStops: [0xF3F6FC, 0xECF2FB, 0xE4EDFA, 0xEAF1FB, 0xF6F9FF],
                glowA: ThemeGlow(darkHex: 0xAAB4C3, lightHex: 0x6AA5FF, darkAlpha: 0.05, lightAlpha: 0.13),
                glowB: ThemeGlow(darkHex: 0x95A1B1, lightHex: 0x7AC9FF, darkAlpha: 0.04, lightAlpha: 0.10),
                glowC: ThemeGlow(darkHex: 0x7F8B9B, lightHex: 0x6CCF8D, darkAlpha: 0.03, lightAlpha: 0.09)
            )

        case .goldenHour:
            return AppThemePalette(
                brandA: 0xFF9F0A,
                brandB: 0xFF6B4A,
                brandC: 0xFFD60A,
                accent: 0xFF9F0A,
                brandMidA: 0xFF7F41,
                brandMidB: 0xFFB347,
                backdropDark: 0x15110D,
                backdropLight: 0xFFF8ED,
                bgDarkStops: [0x17120D, 0x1A1410, 0x201812, 0x17130F, 0x120F0B],
                bgLightStops: [0xFFF6E9, 0xFFF1E0, 0xFFE9D4, 0xFFF0DF, 0xFFF7EC],
                glowA: ThemeGlow(darkHex: 0xC8A27C, lightHex: 0xFFB347, darkAlpha: 0.06, lightAlpha: 0.13),
                glowB: ThemeGlow(darkHex: 0xC0906A, lightHex: 0xFF8A5C, darkAlpha: 0.05, lightAlpha: 0.11),
                glowC: ThemeGlow(darkHex: 0x9C7D5D, lightHex: 0xFFD37A, darkAlpha: 0.04, lightAlpha: 0.09)
            )

        case .graphite:
            return AppThemePalette(
                brandA: 0x8E9AAF,
                brandB: 0xA7B2C2,
                brandC: 0x7E8A9A,
                accent: 0x97A8BE,
                brandMidA: 0x94A1B3,
                brandMidB: 0xAEB8C7,
                backdropDark: 0x0E1012,
                backdropLight: 0xF2F5F9,
                bgDarkStops: [0x0D0E10, 0x111318, 0x16191F, 0x12151A, 0x0E1013],
                bgLightStops: [0xEEF1F5, 0xE7EBF0, 0xDEE4EC, 0xE8EDF4, 0xF2F5F9],
                glowA: ThemeGlow(darkHex: 0xA9B2BF, lightHex: 0xA7B2C2, darkAlpha: 0.05, lightAlpha: 0.11),
                glowB: ThemeGlow(darkHex: 0x8B95A3, lightHex: 0xC2CAD6, darkAlpha: 0.04, lightAlpha: 0.10),
                glowC: ThemeGlow(darkHex: 0x6F7884, lightHex: 0xD0D7E2, darkAlpha: 0.03, lightAlpha: 0.08)
            )

        case .seaBreeze:
            return AppThemePalette(
                brandA: 0x00B3A4,
                brandB: 0x46E7D4,
                brandC: 0x4CD964,
                accent: 0x00AFA0,
                brandMidA: 0x1BC7B5,
                brandMidB: 0x33DCCC,
                backdropDark: 0x0B1415,
                backdropLight: 0xF1FBF8,
                bgDarkStops: [0x0C1415, 0x0E1B1D, 0x102426, 0x0E1A1B, 0x0B1415],
                bgLightStops: [0xEAF8F6, 0xE2F5F1, 0xD8F0EA, 0xE5F6F2, 0xF0FAF8],
                glowA: ThemeGlow(darkHex: 0x7BAEA9, lightHex: 0x00CFC1, darkAlpha: 0.06, lightAlpha: 0.12),
                glowB: ThemeGlow(darkHex: 0x6E9C97, lightHex: 0x42E2CC, darkAlpha: 0.05, lightAlpha: 0.10),
                glowC: ThemeGlow(darkHex: 0x5E8B87, lightHex: 0x6EE6B1, darkAlpha: 0.04, lightAlpha: 0.09)
            )
        }
    }

    var accentColor: Color {
        Color(hex: palette.accent)
    }

    var previewGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: palette.brandA), Color(hex: palette.brandB), Color(hex: palette.brandC)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
