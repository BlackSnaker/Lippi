import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Design System (iOS26-ish Liquid Glass, improved elements)
// =======================================================
struct DS {
    private static var palette: AppThemePalette { AppTheme.current.palette }

    // Brand palette
    static var brandA: Color { Color(hex: palette.brandA) }
    static var brandB: Color { Color(hex: palette.brandB) }
    static var brandC: Color { Color(hex: palette.brandC) }
    static var accent: Color { Color(hex: palette.accent) }
    static var backdropBase: Color {
        Color(dynamicDark: palette.backdropDark, light: palette.backdropLight)
    }

    // Brand gradient
    static var brand: LinearGradient {
        LinearGradient(
            colors: [
                brandA,
                Color(hex: palette.brandMidA),
                Color(hex: palette.brandMidB),
                brandB
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var brandSoftGradient: LinearGradient {
        LinearGradient(
            colors: [
                brandA.opacity(0.34),
                brandB.opacity(0.22),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var brandIridescent: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.28),
                brandB.opacity(0.30),
                brandA.opacity(0.22),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Background base
    static var bgBase: LinearGradient {
        let dark = palette.bgDarkStops
        let light = palette.bgLightStops
        return LinearGradient(
            colors: [
                Color(dynamicDark: dark[0], light: light[0]),
                Color(dynamicDark: dark[1], light: light[1]),
                Color(dynamicDark: dark[2], light: light[2]),
                Color(dynamicDark: dark[3], light: light[3]),
                Color(dynamicDark: dark[4], light: light[4])
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Glows
    static var bgGlowA: Color {
        let glow = palette.glowA
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }
    static var bgGlowB: Color {
        let glow = palette.glowB
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }
    static var bgGlowC: Color {
        let glow = palette.glowC
        return Color(
            dynamicDark: glow.darkHex,
            light: glow.lightHex,
            darkAlpha: glow.darkAlpha,
            lightAlpha: glow.lightAlpha
        )
    }

    // Surfaces
    static let glass = Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.09, lightAlpha: 0.70)
    static let brandSoft = Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.10, lightAlpha: 0.66)

    // Glass tint
    static let glassTint = LinearGradient(
        colors: [
            Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.14, lightAlpha: 0.64),
            Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.05, lightAlpha: 0.34),
            Color(dynamicDark: 0x0B1A31, light: 0xD8E2F3, darkAlpha: 0.42, lightAlpha: 0.78)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassDepth = LinearGradient(
        colors: [
            Color(dynamicDark: 0x10233F, light: 0xF3F7FF, darkAlpha: 0.40, lightAlpha: 0.62),
            Color(dynamicDark: 0x0B1B31, light: 0xE8F0FF, darkAlpha: 0.52, lightAlpha: 0.68),
            Color(dynamicDark: 0x071121, light: 0xDDE7FA, darkAlpha: 0.62, lightAlpha: 0.74)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Specular
    static let specular = LinearGradient(
        colors: [
            Color.white.opacity(0.34),
            Color.white.opacity(0.10),
            Color.clear
        ],
        startPoint: .topLeading,
        endPoint: .center
    )

    static let liquidSheen = LinearGradient(
        colors: [
            Color.white.opacity(0.32),
            Color.white.opacity(0.10),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Subtle top sheen
    static let sheen = LinearGradient(
        colors: [
            Color.white.opacity(0.10),
            Color.white.opacity(0.04),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .center
    )

    // Strokes
    static let shadow = Color(dynamicDark: 0x000000, light: 0x0F172A, darkAlpha: 0.42, lightAlpha: 0.14)
    static let stroke = LinearGradient(
        colors: [
            Color(dynamicDark: 0xFFFFFF, light: 0x111827, darkAlpha: 0.34, lightAlpha: 0.18),
            Color(dynamicDark: 0xFFFFFF, light: 0x111827, darkAlpha: 0.12, lightAlpha: 0.08),
            Color(dynamicDark: 0xFFFFFF, light: 0x111827, darkAlpha: 0.06, lightAlpha: 0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let strokeInner = LinearGradient(
        colors: [
            Color(dynamicDark: 0xFFFFFF, light: 0x111827, darkAlpha: 0.17, lightAlpha: 0.11),
            Color.clear,
            Color(dynamicDark: 0x000000, light: 0x111827, darkAlpha: 0.20, lightAlpha: 0.07)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Tokens
    static let radius: CGFloat = 24
    static let pad: CGFloat = 20

    // Motion tokens: one source of truth for smooth, consistent animations.
    static let motionQuick = Animation.spring(response: 0.28, dampingFraction: 0.90, blendDuration: 0.10)
    static let motionSmooth = Animation.spring(response: 0.40, dampingFraction: 0.91, blendDuration: 0.14)
    static let motionGentle = Animation.spring(response: 0.54, dampingFraction: 0.92, blendDuration: 0.16)
    static let motionEnter = Animation.spring(response: 0.50, dampingFraction: 0.90, blendDuration: 0.16)
    static let motionFadeQuick = Animation.easeOut(duration: 0.20)

    static let pressScale: CGFloat = 0.988
    static let press = motionQuick

    // Extra polish
    static let hairline: CGFloat = 0.85
    static let innerGlow = Color(dynamicDark: 0xFFFFFF, light: 0x111827, darkAlpha: 0.06, lightAlpha: 0.04)
    static let surfaceLift = Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.040, lightAlpha: 0.42)
    static let textPrimary = Color(dynamicDark: 0xFFFFFF, light: 0x0F172A, darkAlpha: 0.95, lightAlpha: 0.95)
    static let textSecondary = Color(dynamicDark: 0xFFFFFF, light: 0x1E293B, darkAlpha: 0.72, lightAlpha: 0.72)
    static let textTertiary = Color(dynamicDark: 0xFFFFFF, light: 0x334155, darkAlpha: 0.56, lightAlpha: 0.56)

    // “Ambient” highlight for pills/buttons
    static let pillGlow = LinearGradient(
        colors: [Color.white.opacity(0.20), Color.clear],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let cardTopLine = LinearGradient(
        colors: [
            Color.white.opacity(0.20),
            Color.white.opacity(0.06),
            Color.clear
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Haptics fallback
    static func hapticSoft() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }

    static var runtimeConstrained: Bool {
        let p = ProcessInfo.processInfo
        #if os(iOS)
        let displayConstrained = UIScreen.main.maximumFramesPerSecond <= 60
        #else
        let displayConstrained = false
        #endif
        return displayConstrained
            || p.isLowPowerModeEnabled
            || p.thermalState == .serious
            || p.thermalState == .critical
    }

    static func text(_ opacity: Double = 1.0) -> Color {
        Color(dynamicDark: 0xFFFFFF, light: 0x0F172A, darkAlpha: opacity, lightAlpha: opacity)
    }

    static func glassFill(_ darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
        let resolvedLight = lightOpacity ?? min(0.90, 0.34 + (darkOpacity * 3.0))
        return Color(
            dynamicDark: 0xFFFFFF,
            light: 0xFFFFFF,
            darkAlpha: darkOpacity,
            lightAlpha: resolvedLight
        )
    }

    static func glassStroke(_ darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
        let resolvedLight = lightOpacity ?? min(0.28, max(0.04, darkOpacity * 0.70))
        return Color(
            dynamicDark: 0xFFFFFF,
            light: 0x111827,
            darkAlpha: darkOpacity,
            lightAlpha: resolvedLight
        )
    }

    static func depthShadow(_ darkOpacity: Double, lightOpacity: Double? = nil) -> Color {
        let resolvedLight = lightOpacity ?? min(0.24, max(0.04, darkOpacity * 0.52))
        return Color(
            dynamicDark: 0x000000,
            light: 0x0F172A,
            darkAlpha: darkOpacity,
            lightAlpha: resolvedLight
        )
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff)/255
        let g = Double((hex >> 8) & 0xff)/255
        let b = Double(hex & 0xff)/255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    init(dynamicDark darkHex: UInt, light lightHex: UInt, darkAlpha: Double = 1.0, lightAlpha: Double = 1.0) {
        #if os(iOS)
        self = Color(
            UIColor { trait in
                if trait.userInterfaceStyle == .dark {
                    return UIColor(hex: darkHex, alpha: darkAlpha)
                } else {
                    return UIColor(hex: lightHex, alpha: lightAlpha)
                }
            }
        )
        #else
        self.init(hex: darkHex, alpha: darkAlpha)
        #endif
    }
}

#if os(iOS)
private extension UIColor {
    convenience init(hex: UInt, alpha: Double = 1.0) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8) & 0xff) / 255
        let b = CGFloat(hex & 0xff) / 255
        self.init(red: r, green: g, blue: b, alpha: CGFloat(alpha))
    }
}
#endif

// ==== Text tightening helpers
extension View {
    func singleLine() -> some View {
        self
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .allowsTightening(true)
            .truncationMode(.tail)
    }

    func lippiWindowChrome() -> some View {
        self.overlay(LippiWindowChrome())
    }
}

struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title.singleLine()
        }
    }
}

private struct LippiWindowChrome: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var simplified: Bool { DS.runtimeConstrained || reduceTransparency }

    var body: some View {
        GeometryReader { proxy in
            let top = max(104, proxy.safeAreaInsets.top + 82)
            let bottom = max(124, proxy.safeAreaInsets.bottom + 94)

            ZStack {
                LinearGradient(
                    colors: [
                        Color.white.opacity(scheme == .dark ? (simplified ? 0.05 : 0.09) : 0.12),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: top)
                .frame(maxHeight: .infinity, alignment: .top)

                LinearGradient(
                    colors: [
                        .clear,
                        Color.black.opacity(scheme == .dark ? (simplified ? 0.12 : 0.17) : 0.08)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: bottom)
                .frame(maxHeight: .infinity, alignment: .bottom)

                if !simplified {
                    AngularGradient(
                        colors: [
                            Color.white.opacity(scheme == .dark ? 0.048 : 0.034),
                            .clear,
                            Color.white.opacity(scheme == .dark ? 0.032 : 0.022),
                            .clear
                        ],
                        center: .center
                    )
                    .opacity(0.68)
                    .blendMode(.overlay)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// =======================================================
// MARK: - Unified Section Header
// =======================================================
struct LippiSectionHeader: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let title: String
    var subtitle: String? = nil
    var icon: String
    var accent: Color = DS.accent

    private var simplified: Bool { DS.runtimeConstrained || reduceTransparency }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(DS.glassFill(simplified ? 0.10 : 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(accent.opacity(simplified ? 0.18 : 0.24))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(DS.glassStroke(0.16), lineWidth: 1)
                    )

                if !simplified {
                    Circle()
                        .fill(accent.opacity(0.30))
                        .blur(radius: 7)
                        .offset(x: 5, y: -5)
                }

                Image(safeSystemName: icon, fallback: "circle.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.text(0.95))
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .singleLine()

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.text(0.62))
                        .singleLine()
                }
            }

            Spacer(minLength: 8)

            if !simplified {
                Circle()
                    .fill(accent.opacity(0.72))
                    .frame(width: 5, height: 5)
                    .shadow(color: accent.opacity(0.45), radius: 5, x: 0, y: 1)
                    .padding(.trailing, 1)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.58), accent.opacity(0.18), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1.2)
                .offset(y: 10)
        }
        .padding(.bottom, 8)
    }
}

// =======================================================
// MARK: - Micro Noise (subtle, animated-free, cheaper)
// =======================================================
private struct MicroNoise: View {
    var opacity: Double = 0.075
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 9
            for y in stride(from: 0 as CGFloat, to: size.height, by: step) {
                for x in stride(from: 0 as CGFloat, to: size.width, by: step) {
                    // deterministic, but less “grid-looking”
                    let v = (sin((x * 0.11) + (y * 0.17)) + cos((x + y) * 0.07)) * 0.5
                    if v > 0.78 {
                        ctx.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color(.white.opacity(0.05)))
                    }
                }
            }
        }
        .opacity(opacity)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// =======================================================
// MARK: - GlassCard (better depth + nicer specular + crisper edges)
// =======================================================
enum GlassCardStyle {
    case full
    case lightweight
    case flat
}

struct GlassCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var padding: CGFloat = DS.pad
    var cornerRadius: CGFloat = DS.radius
    var style: GlassCardStyle = .lightweight
    var animateOnAppear: Bool = false
    @ViewBuilder var content: Content
    @State private var didAppear = false

    private var performanceMode: Bool { DS.runtimeConstrained || reduceTransparency }
    private var useFlatEffects: Bool { style == .flat || performanceMode }
    private var useLightEffects: Bool { useFlatEffects || style == .lightweight }
    private var useFullEffects: Bool { style == .full && !performanceMode }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground.allowsHitTesting(false))
            .overlay(cardBorder.allowsHitTesting(false))
            .overlay(alignment: .topLeading) {
                topLine.allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) {
                fullModeBottomAccent.allowsHitTesting(false)
            }
            // двойная тень: мягкая “подушка” + более близкая
            .shadow(
                color: primaryShadowColor,
                radius: primaryShadowRadius,
                x: 0,
                y: primaryShadowY
            )
            .shadow(
                color: secondaryShadowColor,
                radius: secondaryShadowRadius,
                x: 0,
                y: secondaryShadowY
            )
            .opacity(appearOpacity)
            .offset(y: appearOffset)
            .scaleEffect(appearScale)
            .animation(reduceMotion ? nil : DS.motionQuick, value: cornerRadius)
            .onAppear {
                guard animateOnAppear else { return }
                guard !performanceMode else {
                    didAppear = true
                    return
                }
                guard !didAppear else { return }
                if reduceMotion {
                    didAppear = true
                } else {
                    withAnimation(DS.motionEnter) {
                        didAppear = true
                    }
                }
            }
    }

    private var appearOpacity: Double {
        (reduceMotion || !animateOnAppear || didAppear) ? 1.0 : 0.001
    }

    private var appearOffset: CGFloat {
        (reduceMotion || !animateOnAppear || didAppear) ? 0 : 10
    }

    private var appearScale: CGFloat {
        (reduceMotion || !animateOnAppear || didAppear) ? 1.0 : 0.988
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = cardShape
        if useFlatEffects {
            shape
                .fill(DS.glassFill(0.065))
                .overlay { shape.fill(DS.glassTint).opacity(0.10) }
        } else if useLightEffects {
            shape
                .fill(DS.glassFill(0.08))
                .overlay { shape.fill(DS.glassDepth).opacity(0.12) }
                .overlay { shape.fill(DS.glassTint).opacity(0.19) }
                .overlay { shape.fill(DS.surfaceLift).opacity(0.15) }
        } else {
            fullModeBackground(shape: shape)
        }
    }

    @ViewBuilder
    private var cardBorder: some View {
        let shape = cardShape
        shape
            .stroke(DS.stroke, lineWidth: useFlatEffects ? 0.7 : DS.hairline)
            .overlay {
                if useFullEffects {
                    shape
                        .stroke(DS.strokeInner, lineWidth: 1)
                        .padding(1)
                        .blendMode(.overlay)
                }
            }
            .overlay {
                if useFullEffects {
                    shape
                        .stroke(DS.innerGlow, lineWidth: 1)
                        .padding(2)
                        .blendMode(.screen)
                }
            }
    }

    private var topLine: some View {
        Capsule()
            .fill(DS.cardTopLine)
            .frame(width: useFlatEffects ? 54 : (useFullEffects ? 90 : 70), height: useFlatEffects ? 1 : 1.2)
            .opacity(useFlatEffects ? 0.68 : 1.0)
            .padding(.top, 8)
            .padding(.leading, 14)
    }

    @ViewBuilder
    private var fullModeBottomAccent: some View {
        if useFullEffects {
            Capsule()
                .fill(DS.brandIridescent)
                .frame(width: 68, height: 1.15)
                .rotationEffect(.degrees(-13))
                .opacity(0.54)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
        }
    }

    private var primaryShadowColor: Color {
        DS.shadow.opacity(useFlatEffects ? 0.06 : (useLightEffects ? 0.16 : 0.34))
    }
    private var primaryShadowRadius: CGFloat {
        useFlatEffects ? 1.2 : (useLightEffects ? 3 : 12)
    }
    private var primaryShadowY: CGFloat {
        useFlatEffects ? 1 : (useLightEffects ? 2 : 7)
    }
    private var secondaryShadowColor: Color {
        DS.shadow.opacity(useFlatEffects ? 0.0 : (useFullEffects ? 0.10 : 0.0))
    }
    private var secondaryShadowRadius: CGFloat {
        useFlatEffects ? 0 : (useFullEffects ? 4 : 0)
    }
    private var secondaryShadowY: CGFloat {
        useFlatEffects ? 0 : (useFullEffects ? 2 : 0)
    }

    private func fullModeBackground(shape: RoundedRectangle) -> some View {
        shape
            .fill(DS.glass)
            .overlay { shape.fill(DS.glassDepth).opacity(0.34) }
            .overlay { shape.fill(DS.glassTint).opacity(0.80) }
            .overlay {
                shape
                    .fill(DS.brandIridescent)
                    .opacity(0.50)
                    .blendMode(.screen)
            }
            .overlay { shape.fill(DS.surfaceLift).blendMode(.overlay) }
            .overlay {
                shape
                    .fill(DS.sheen)
                    .opacity(0.58)
                    .blendMode(.screen)
                    .mask(
                        LinearGradient(
                            colors: [.white, .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
            .overlay {
                shape
                    .fill(DS.specular)
                    .opacity(0.54)
                    .blendMode(.screen)
                    .mask(
                        RadialGradient(
                            colors: [.white, .white.opacity(0)],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
            }
            .overlay {
                shape
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .blendMode(.screen)
                    .opacity(0.72)
            }
    }
}

// =======================================================
// MARK: - Buttons (cleaner pills + better pressed/disabled)
// =======================================================
struct LippiButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive, ghost }
    var kind: Kind = .primary
    var compact: Bool = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var simplifiedEffects: Bool { DS.runtimeConstrained || reduceTransparency }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .singleLine()
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 9 : 12)
            .frame(minHeight: compact ? 34 : 40)
            .background(background(pressed: pressed))
            .overlay(borderOverlay(pressed: pressed))
            .overlay(sheenOverlay(pressed: pressed))
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .opacity(isEnabled ? 1.0 : disabledOpacity)
            .saturation(isEnabled ? 1.0 : 0.86)
            .brightness(isEnabled ? 0 : -0.02)
            .scaleEffect(reduceMotion ? 1 : (pressed ? DS.pressScale : 1))
            .shadow(
                color: shadowColor(pressed: pressed),
                radius: pressed ? 3 : (kind == .primary ? (simplifiedEffects ? 5 : 8) : (simplifiedEffects ? 3 : 5)),
                x: 0,
                y: pressed ? 1 : (kind == .primary ? 4 : 2)
            )
            .animation(reduceMotion ? nil : DS.press, value: pressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, isEnabled { DS.hapticSoft() }
            }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch kind {
        case .primary:
            Capsule()
                .fill(DS.brand)
                .overlay(
                    Capsule()
                        .fill(DS.brandIridescent)
                        .blendMode(.screen)
                        .opacity(simplifiedEffects ? (pressed ? 0.24 : 0.40) : (pressed ? 0.45 : 0.72))
                )
                .opacity(pressed ? 0.92 : 1.0)
        case .secondary:
            Capsule()
                .fill(DS.glassFill(pressed ? 0.18 : 0.13))
                .overlay(
                    Capsule()
                        .fill(DS.glassTint)
                        .opacity(simplifiedEffects ? (pressed ? 0.10 : 0.18) : (pressed ? 0.18 : 0.34))
                )
                .overlay(
                    Group {
                        if !simplifiedEffects {
                            Capsule()
                                .fill(DS.brandSoftGradient)
                                .blendMode(.screen)
                                .opacity(pressed ? 0.12 : 0.26)
                        }
                    }
                )
        case .destructive:
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.red.opacity(0.34), Color.red.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(pressed ? 0.85 : 1.0)
        case .ghost:
            Capsule()
                .fill(DS.glassFill(pressed ? 0.08 : 0.04))
                .overlay(
                    Capsule()
                        .fill(DS.glassTint)
                        .opacity(pressed ? 0.10 : 0.18)
                )
        }
    }

    private func borderOverlay(pressed: Bool) -> some View {
        Capsule()
            .strokeBorder(borderColor(pressed: pressed), lineWidth: 1)
            .overlay(
                Group {
                    if !simplifiedEffects {
                        Capsule()
                            .strokeBorder(DS.glassStroke(pressed ? 0.22 : 0.10), lineWidth: 1)
                            .padding(1)
                    }
                }
            )
    }

    private func sheenOverlay(pressed: Bool) -> some View {
        Group {
            if !simplifiedEffects {
                Capsule()
                    .fill(DS.liquidSheen)
                    .opacity(pressed ? 0.10 : (kind == .ghost ? 0.09 : 0.26))
                    .mask(
                        LinearGradient(
                            colors: [.white, .white.opacity(0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        }
    }

    private func borderColor(pressed: Bool) -> Color {
        let boost: Double = pressed ? 0.09 : 0.0
        switch kind {
        case .primary:     return DS.glassStroke(0.24 + boost)
        case .secondary:   return DS.glassStroke(0.19 + boost)
        case .destructive: return .red.opacity(0.34 + boost)
        case .ghost:       return DS.glassStroke(0.16 + boost)
        }
    }

    private var foreground: some ShapeStyle {
        switch kind {
        case .primary:     return AnyShapeStyle(DS.text())
        case .secondary:   return AnyShapeStyle(DS.text(0.94))
        case .destructive: return AnyShapeStyle(Color.red.opacity(0.92))
        case .ghost:       return AnyShapeStyle(DS.text(0.92))
        }
    }

    private var disabledOpacity: Double {
        switch kind {
        case .primary: 0.55
        case .secondary: 0.52
        case .destructive: 0.50
        case .ghost: 0.45
        }
    }

    private func shadowColor(pressed: Bool) -> Color {
        guard isEnabled else { return .clear }
        switch kind {
        case .primary:
            return DS.accent.opacity(pressed ? 0.20 : 0.34)
        case .secondary:
            return DS.depthShadow(pressed ? 0.10 : 0.18)
        case .destructive:
            return Color.red.opacity(pressed ? 0.16 : 0.24)
        case .ghost:
            return .clear
        }
    }
}

// =======================================================
// MARK: - Ring Progress + Confetti (Premium)
// =======================================================
struct RingProgressView: View, Animatable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var progress: Double
    var lineWidth: CGFloat = 14

    // ✅ FIX: Animatable setter реально обновляет progress
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    @State private var didComplete = false
    @State private var showCheck = false

    var body: some View {
        let clamped = max(0, min(1, progress))

        ZStack {
            Circle()
                .fill(DS.glassFill(0.05))
                .overlay(Circle().fill(DS.glassTint).opacity(0.34))

            Circle()
                .stroke(DS.glassStroke(0.12), lineWidth: lineWidth)

            if !didComplete {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        DS.brand,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                    .overlay(
                        Circle()
                            .trim(from: 0, to: clamped)
                            .stroke(
                                DS.brandIridescent,
                                style: StrokeStyle(lineWidth: max(1, lineWidth * 0.42), lineCap: .round, lineJoin: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .blendMode(.screen)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if didComplete {
                Circle()
                    .fill(DS.brand)
                    .overlay(Circle().fill(DS.brandIridescent).blendMode(.screen))

                if showCheck {
                    Image(safeSystemName: "checkmark", fallback: "checkmark")
                        .font(.system(size: max(18, lineWidth * 1.5), weight: .bold))
                        .foregroundStyle(DS.text())
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: progress) { _, new in
            let v = max(0, min(1, new))
            if v >= 1.0, !didComplete {
                completeSequence()
            } else if v < 1.0, didComplete {
                didComplete = false
                showCheck = false
            }
        }
        .accessibilityLabel(Text(didComplete ? "Сессия завершена" : "Прогресс"))
        .accessibilityValue(Text("\(Int(clamped * 100))%"))
    }

    private func completeSequence() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        didComplete = true
        if reduceMotion {
            showCheck = true
        } else {
            withAnimation(DS.motionFadeQuick) { showCheck = true }
        }
    }
}

// =======================================================
// MARK: - Fancy Linear Progress Bar (Premium)
// =======================================================
struct FancyLinearProgressBar: View {
    var progress: Double         // 0...1
    var height: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            let p = max(0, min(1, progress))
            let w = geo.size.width
            let h = height
            let r = h / 2

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(DS.glassFill(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(DS.glassTint)
                            .opacity(0.28)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .stroke(DS.glassStroke(0.14), lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .fill(DS.brand)
                    .overlay(
                        RoundedRectangle(cornerRadius: r, style: .continuous)
                            .fill(DS.brandIridescent)
                            .blendMode(.screen)
                            .opacity(0.52)
                    )
                    .frame(width: max(h, w * p), height: h)
            }
            .frame(height: h)
            .transaction { $0.animation = nil }
        }
        .frame(height: height)
        .accessibilityLabel(Text("Прогресс"))
        .accessibilityValue(Text("\(Int(max(0, min(1, progress)) * 100))%"))
    }
}

// =======================================================
// MARK: - Animated Background (Smooth + Premium) — NO LAG (GPU Canvas)
// =======================================================
struct AnimatedBackground: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale

    // Тюнинг производительности
    private let targetFPS: Double = 16
    private let globalBlurCap: CGFloat = 36
    private let blobEdgeSoftness: CGFloat = 0.72

    // Low Power Mode (жёстко режем нагрузку, если включён)
    private var lowPower: Bool { DS.runtimeConstrained }
    private var effectiveFPS: Double { lowPower ? 10 : targetFPS }
    private var enableGlowBlend: Bool { !lowPower && !reduceMotion } // plusLighter дорогой при скролле

    var body: some View {
        ZStack {
            DS.bgBase

            if reduceMotion {
                // Статическая версия (без Timeline)
                Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { ctx, size in
                    let w = size.width, h = size.height, m = max(w, h)
                    drawBlobs(in: &ctx, size: size, t: 0, w: w, h: h, m: m)
                }
            } else {
                TimelineView(.periodic(from: .now, by: 1.0 / max(10, effectiveFPS))) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate

                    Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { ctx, size in
                        let w = size.width, h = size.height, m = max(w, h)

                        // Глобальный blur один раз (с понижением в Low Power)
                        let blurBase = m * (lowPower ? 0.018 : 0.028)
                        let blur = min(globalBlurCap, blurBase)
                        if blur > 0 { ctx.addFilter(.blur(radius: blur)) }

                        // Свечение: в Low Power отключаем (экономит заметно)
                        if enableGlowBlend {
                            ctx.blendMode = .plusLighter
                        }

                        drawBlobs(in: &ctx, size: size, t: t, w: w, h: h, m: m)
                    }
                    .transaction { $0.animation = nil } // чтобы родительские анимации не дергали фон
                }
            }

            // Спекулярный налёт (дёшево)
            AngularGradient(
                colors: [
                    .white.opacity(0.030),
                    .clear,
                    .white.opacity(0.018),
                    .clear,
                    .white.opacity(0.024),
                    .clear
                ],
                center: .center
            )
            .blendMode(.screen)
            .opacity(scheme == .dark ? (lowPower ? 0.40 : 0.55) : (lowPower ? 0.32 : 0.42))
        }
        .overlay(vignette)
        .saturation(scheme == .dark ? 1.02 : 0.98)
        .contrast(1.02)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var vignette: some View {
        RadialGradient(
            colors: [
                .clear,
                .black.opacity(scheme == .dark ? 0.10 : 0.06),
                .black.opacity(scheme == .dark ? 0.16 : 0.10)
            ],
            center: .center,
            startRadius: 80,
            endRadius: 520
        )
        .blendMode(.multiply)
    }

    // MARK: - Canvas Drawing

    private func drawBlobs(in ctx: inout GraphicsContext, size: CGSize, t: TimeInterval, w: CGFloat, h: CGFloat, m: CGFloat) {
        // Квантуем позицию (стабильнее на ретине/скролле)
        let q: CGFloat = max(0.75, 1.0 / displayScale)

        if lowPower || reduceMotion {
            drawBlob(
                in: &ctx,
                color: DS.bgGlowA,
                t: t,
                speed: 0.044,
                xAmp: 0.18, yAmp: 0.16,
                base: .topLeading,
                phase: 0.0,
                sizeMul: 0.92,
                w: w, h: h, m: m,
                q: q
            )
            drawBlob(
                in: &ctx,
                color: DS.bgGlowC,
                t: t,
                speed: 0.028,
                xAmp: 0.16, yAmp: 0.15,
                base: .bottomTrailing,
                phase: 2.3,
                sizeMul: 0.98,
                w: w, h: h, m: m,
                q: q
            )
            return
        }

        drawBlob(
            in: &ctx,
            color: DS.bgGlowA,
            t: t,
            speed: 0.052,
            xAmp: 0.24, yAmp: 0.20,
            base: .topLeading,
            phase: 0.0,
            sizeMul: 1.08,
            w: w, h: h, m: m,
            q: q
        )

        drawBlob(
            in: &ctx,
            color: DS.bgGlowB,
            t: t,
            speed: 0.041,
            xAmp: 0.26, yAmp: 0.24,
            base: .center,
            phase: 1.7,
            sizeMul: 0.96,
            w: w, h: h, m: m,
            q: q
        )

        drawBlob(
            in: &ctx,
            color: DS.bgGlowC,
            t: t,
            speed: 0.031,
            xAmp: 0.22, yAmp: 0.22,
            base: .bottomTrailing,
            phase: 3.1,
            sizeMul: 1.12,
            w: w, h: h, m: m,
            q: q
        )
    }

    private func drawBlob(
        in ctx: inout GraphicsContext,
        color: Color,
        t: TimeInterval,
        speed: Double,
        xAmp: CGFloat,
        yAmp: CGFloat,
        base: UnitPoint,
        phase: Double,
        sizeMul: CGFloat,
        w: CGFloat,
        h: CGFloat,
        m: CGFloat,
        q: CGFloat
    ) {
        let basePoint = baseCGPoint(base, w: w, h: h)

        let tt = (t * speed) + phase
        let dx = xAmp * w * CGFloat(sin(tt * 1.6) * 0.74 + sin(tt * 0.75) * 0.26)
        let dy = yAmp * h * CGFloat(cos(tt * 1.35) * 0.70 + cos(tt * 0.62) * 0.30)

        let breathe = CGFloat(0.030 * sin(tt * 0.95))
        let radius = (m * 0.46 * sizeMul) * (1.0 + breathe)

        // Квантуем позицию
        let rawX = basePoint.x + dx
        let rawY = basePoint.y + dy
        let cx = (rawX / q).rounded() * q
        let cy = (rawY / q).rounded() * q
        let center = CGPoint(x: cx, y: cy)

        // Мягкая радиальная заливка (без индивидуального blur на blob)
        let g = Gradient(stops: [
            .init(color: color.opacity(0.90), location: 0.0),
            .init(color: color.opacity(0.52), location: 0.35),
            .init(color: color.opacity(0.18), location: 0.62),
            .init(color: .clear,              location: blobEdgeSoftness)
        ])

        let shading = GraphicsContext.Shading.radialGradient(
            g,
            center: center,
            startRadius: 0,
            endRadius: radius
        )

        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: shading, style: .init(eoFill: true, antialiased: true))
    }

    private func baseCGPoint(_ base: UnitPoint, w: CGFloat, h: CGFloat) -> CGPoint {
        switch base {
        case .topLeading:     return CGPoint(x: w * 0.20, y: h * 0.22)
        case .top:            return CGPoint(x: w * 0.50, y: h * 0.22)
        case .topTrailing:    return CGPoint(x: w * 0.80, y: h * 0.22)
        case .leading:        return CGPoint(x: w * 0.22, y: h * 0.50)
        case .center:         return CGPoint(x: w * 0.50, y: h * 0.50)
        case .trailing:       return CGPoint(x: w * 0.78, y: h * 0.50)
        case .bottomLeading:  return CGPoint(x: w * 0.22, y: h * 0.78)
        case .bottom:         return CGPoint(x: w * 0.50, y: h * 0.78)
        case .bottomTrailing: return CGPoint(x: w * 0.78, y: h * 0.78)
        default:              return CGPoint(x: w * 0.50, y: h * 0.50)
        }
    }
}
