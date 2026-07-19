import SwiftUI
#if os(iOS)
import UIKit
#endif

// =======================================================
// MARK: - Adaptive Apple design system
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
    static var solidSurface: Color {
        Color(
            dynamicDark: palette.bgDarkStops[1],
            light: palette.bgLightStops[1],
            darkAlpha: 0.98,
            lightAlpha: 0.98
        )
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
    static let glass = Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.11, lightAlpha: 0.74)
    static let brandSoft = Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.12, lightAlpha: 0.70)

    // Glass tint
    static let glassTint = LinearGradient(
        colors: [
            Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.18, lightAlpha: 0.70),
            Color(dynamicDark: 0xFFFFFF, light: 0xFFFFFF, darkAlpha: 0.07, lightAlpha: 0.42),
            Color(dynamicDark: 0x0B1A31, light: 0xD8E2F3, darkAlpha: 0.46, lightAlpha: 0.82)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let glassDepth = LinearGradient(
        colors: [
            Color(dynamicDark: 0x10233F, light: 0xF3F7FF, darkAlpha: 0.44, lightAlpha: 0.66),
            Color(dynamicDark: 0x0B1B31, light: 0xE8F0FF, darkAlpha: 0.56, lightAlpha: 0.72),
            Color(dynamicDark: 0x071121, light: 0xDDE7FA, darkAlpha: 0.66, lightAlpha: 0.78)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let liquidSheen = LinearGradient(
        colors: [
            Color.white.opacity(0.38),
            Color.white.opacity(0.14),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // Subtle top sheen
    static let sheen = LinearGradient(
        colors: [
            Color.white.opacity(0.14),
            Color.white.opacity(0.06),
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

    // Motion tokens: brief, precise springs with a shared rhythm across the app.
    // Duration/bounce parameters use the spring model standardized across Apple frameworks.
    static let motionPress = Animation.spring(duration: 0.18, bounce: 0.00, blendDuration: 0.02)
    static let motionQuick = Animation.spring(duration: 0.22, bounce: 0.02, blendDuration: 0.03)
    static let motionState = Animation.spring(duration: 0.28, bounce: 0.04, blendDuration: 0.04)
    static let motionTabSwitch = Animation.spring(duration: 0.32, bounce: 0.06, blendDuration: 0.05)
    static let motionSmooth = Animation.spring(duration: 0.34, bounce: 0.04, blendDuration: 0.05)
    static let motionEnter = Animation.spring(duration: 0.38, bounce: 0.03, blendDuration: 0.06)
    static let motionNavigate = Animation.spring(duration: 0.40, bounce: 0.02, blendDuration: 0.06)
    static let motionReveal = Animation.spring(duration: 0.40, bounce: 0.02, blendDuration: 0.06)
    static let motionMagic = Animation.spring(duration: 0.42, bounce: 0.04, blendDuration: 0.06)
    static let motionGentle = Animation.spring(duration: 0.46, bounce: 0.00, blendDuration: 0.08)
    static let motionSweep = Animation.easeInOut(duration: 5.8)
    static let motionFadeQuick = Animation.easeOut(duration: 0.16)

    static let pressScale: CGFloat = 0.985
    static let press = motionPress

    // Extra polish
    static let hairline: CGFloat = 0.85
    static let textPrimary = Color(dynamicDark: 0xFFFFFF, light: 0x0F172A, darkAlpha: 0.95, lightAlpha: 0.95)
    static let textSecondary = Color(dynamicDark: 0xFFFFFF, light: 0x1E293B, darkAlpha: 0.72, lightAlpha: 0.72)
    static let textTertiary = Color(dynamicDark: 0xFFFFFF, light: 0x334155, darkAlpha: 0.56, lightAlpha: 0.56)

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
        #if targetEnvironment(simulator)
        return
        #else
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
        #endif
    }

    static var runtimeConstrained: Bool {
        let p = ProcessInfo.processInfo
        return p.isLowPowerModeEnabled
            || p.thermalState == .serious
            || p.thermalState == .critical
    }

    static var performanceEffectsReduced: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return runtimeConstrained
        #endif
    }

    static var systemGlassEffectsEnabled: Bool {
        !performanceEffectsReduced
    }

    static var displayMaximumFramesPerSecond: Int {
        #if os(iOS)
        max(60, UIScreen.main.maximumFramesPerSecond)
        #else
        60
        #endif
    }

    static var preferredFramesPerSecond: Int {
        runtimeConstrained ? min(60, displayMaximumFramesPerSecond) : displayMaximumFramesPerSecond
    }

    static var animationFrameInterval: TimeInterval {
        1.0 / Double(max(60, preferredFramesPerSecond))
    }

    static func animationFrameInterval(active: Bool, reduceMotion: Bool) -> TimeInterval {
        if !active { return 1.0 }
        if reduceMotion { return 1.0 / 30.0 }
        return animationFrameInterval
    }

    static func animationFrameInterval(active: Bool, reduceMotion: Bool, isScrolling: Bool) -> TimeInterval {
        if !active { return 1.0 }
        if reduceMotion || isScrolling || runtimeConstrained { return 1.0 / 30.0 }
        return animationFrameInterval
    }

    static func motionStaggerDelay(_ index: Int, step: Double = 0.028, cap: Double = 0.14) -> Double {
        min(cap, max(0, Double(index)) * step)
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

    /// Keeps readable content widths on iPad and compact widths on iPhone.
    func lippiContentColumn(maxWidth: CGFloat = 760, padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func lippiSystemGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false,
        prominent: Bool = false,
        enabled: Bool = true,
        forceSystemGlass: Bool = false
    ) -> some View {
        modifier(
            LippiSystemGlassModifier(
                shape: shape,
                tint: tint,
                interactive: interactive,
                prominent: prominent,
                enabled: enabled,
                forceSystemGlass: forceSystemGlass
            )
        )
    }

    func lippiMagicAppear(
        _ enabled: Bool = true,
        delay: Double = 0,
        y: CGFloat = 10,
        scale: CGFloat = 0.992
    ) -> some View {
        modifier(
            LippiMagicAppearModifier(
                enabled: enabled,
                delay: delay,
                y: y,
                initialScale: scale
            )
        )
    }

    func lippiMotionScene(
        _ index: Int = 0,
        enabled: Bool = true,
        y: CGFloat = 10
    ) -> some View {
        modifier(
            LippiMotionSceneModifier(
                index: index,
                enabled: enabled,
                y: y
            )
        )
    }

    func lippiFloating(
        active: Bool = true,
        amplitude: CGFloat = 2.5,
        duration: Double = 5.4
    ) -> some View {
        modifier(
            LippiFloatingModifier(
                active: active,
                amplitude: amplitude,
                duration: duration
            )
        )
    }
}

/// Groups nearby Liquid Glass controls into one compositing region on iOS 26.
/// The fallback deliberately adds no extra layer on older or constrained devices.
struct LippiGlassEffectGroup<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling

    private let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *),
           DS.systemGlassEffectsEnabled,
           !reduceTransparency,
           !isScrolling {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private struct LippiSystemGlassModifier<S: Shape>: ViewModifier {
    @Environment(\.lippiIsScrolling) private var isScrolling
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let shape: S
    let tint: Color?
    let interactive: Bool
    let prominent: Bool
    let enabled: Bool
    let forceSystemGlass: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let shouldRender = enabled
            && (interactive || prominent || forceSystemGlass)
            && (forceSystemGlass || DS.systemGlassEffectsEnabled)
            && !isScrolling
            && !reduceTransparency
        if shouldRender {
            if #available(iOS 26.0, *) {
                content.glassEffect(
                    Glass.regular.tint(tint).interactive(interactive),
                    in: shape
                )
            } else {
                content
            }
        } else {
            content
        }
    }
}

struct LippiLiquidSheen: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling

    var cornerRadius: CGFloat
    var duration: Double = 6.0
    var intensity: Double = 1.0

    private var shouldRender: Bool {
        !reduceTransparency && !isScrolling && !DS.runtimeConstrained
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if shouldRender, size.width > 2, size.height > 2 {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.00),
                        Color.white.opacity(0.24 * intensity),
                        DS.accent.opacity(0.10 * intensity),
                        Color.white.opacity(0.08 * intensity),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(58, size.width * 0.38), height: size.height * 1.9)
                .rotationEffect(.degrees(18))
                .offset(
                    x: -size.width * 0.18,
                    y: -size.height * 0.42
                )
                .blendMode(.screen)
                .opacity(0.38)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LippiMagicAppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lippiIsScrolling) private var isScrolling

    let enabled: Bool
    let delay: Double
    let y: CGFloat
    let initialScale: CGFloat
    @State private var didAppear = false

    private var shouldAnimate: Bool {
        enabled && !reduceMotion && !isScrolling
    }

    func body(content: Content) -> some View {
        content
            .opacity(shouldAnimate ? (didAppear ? 1 : 0.001) : 1)
            .offset(y: shouldAnimate ? (didAppear ? 0 : y) : 0)
            .scaleEffect(shouldAnimate ? (didAppear ? 1 : initialScale) : 1)
            .onAppear {
                guard enabled else {
                    didAppear = true
                    return
                }
                guard shouldAnimate else {
                    didAppear = true
                    return
                }
                guard !didAppear else { return }
                withAnimation(DS.motionMagic.delay(delay)) {
                    didAppear = true
                }
            }
    }
}

private struct LippiMotionSceneModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling

    let index: Int
    let enabled: Bool
    let y: CGFloat
    @State private var didAppear = false

    private var shouldAnimate: Bool {
        enabled && !reduceMotion && !reduceTransparency && !isScrolling && !DS.runtimeConstrained
    }

    func body(content: Content) -> some View {
        content
            .opacity(shouldAnimate ? (didAppear ? 1 : 0.001) : 1)
            .offset(y: shouldAnimate ? (didAppear ? 0 : y) : 0)
            .scaleEffect(shouldAnimate ? (didAppear ? 1 : 0.994) : 1)
            .onAppear {
                guard enabled else {
                    didAppear = true
                    return
                }
                guard shouldAnimate else {
                    didAppear = true
                    return
                }
                guard !didAppear else { return }
                withAnimation(DS.motionReveal.delay(DS.motionStaggerDelay(index))) {
                    didAppear = true
                }
            }
    }
}

private struct LippiFloatingModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling

    let active: Bool
    let amplitude: CGFloat
    let duration: Double
    @State private var phase = false

    private var shouldAnimate: Bool {
        active && !reduceMotion && !reduceTransparency && !isScrolling && !DS.runtimeConstrained
    }

    func body(content: Content) -> some View {
        content
            .offset(y: shouldAnimate ? (phase ? -amplitude : amplitude * 0.35) : 0)
            .scaleEffect(shouldAnimate ? (phase ? 1.006 : 0.998) : 1)
            .onAppear {
                guard shouldAnimate else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
            .onChange(of: shouldAnimate) { _, newValue in
                guard newValue else {
                    phase = false
                    return
                }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    phase = true
                }
            }
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
    @Environment(\.lippiIsScrolling) private var isScrolling

    private var simplified: Bool { DS.performanceEffectsReduced || reduceTransparency || isScrolling }

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
    @Environment(\.lippiIsScrolling) private var isScrolling

    let title: String
    var subtitle: String? = nil
    var icon: String
    var accent: Color = DS.accent

    private var simplified: Bool { DS.performanceEffectsReduced || reduceTransparency || isScrolling }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
            .frame(width: 34, height: 34)
            .lippiSystemGlass(
                in: RoundedRectangle(cornerRadius: 12, style: .continuous),
                tint: accent.opacity(0.12),
                enabled: !simplified
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.text(0.94))
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DS.text(0.62))
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                        .allowsTightening(true)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.bottom, subtitle == nil ? 2 : 4)
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
    @Environment(\.lippiIsScrolling) private var isScrolling

    var padding: CGFloat = DS.pad
    var cornerRadius: CGFloat = DS.radius
    var style: GlassCardStyle = .lightweight
    var animateOnAppear: Bool = false
    var forceSystemGlass: Bool = false
    @ViewBuilder var content: Content
    @State private var didAppear = false

    private var performanceMode: Bool { DS.performanceEffectsReduced || reduceTransparency }
    private var scrollPerformanceMode: Bool { isScrolling }
    private var isFlatStyle: Bool { style == .flat }
    private var useFlatEffects: Bool { style == .flat || performanceMode || scrollPerformanceMode }
    private var useLightEffects: Bool { useFlatEffects || style == .lightweight || isScrolling }
    private var useFullEffects: Bool { style == .full && !performanceMode && !scrollPerformanceMode }
    private var useMagicSheen: Bool {
        style == .full && !reduceTransparency && !reduceMotion && !scrollPerformanceMode
    }
    private var systemGlassEnabled: Bool {
        !reduceTransparency
            && !isScrolling
            && (style == .full || forceSystemGlass)
            && (!performanceMode || forceSystemGlass)
    }
    private var systemGlassTint: Color? {
        if useFullEffects { return DS.accent.opacity(0.18) }
        if isFlatStyle { return DS.accent.opacity(0.055) }
        return DS.accent.opacity(0.10)
    }
    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground.allowsHitTesting(false))
            .overlay(cardBorder.allowsHitTesting(false))
            .overlay {
                if useMagicSheen {
                    LippiLiquidSheen(
                        cornerRadius: cornerRadius,
                        duration: 6.4,
                        intensity: 0.82
                    )
                    .clipShape(cardShape)
                }
            }
            .lippiSystemGlass(
                in: cardShape,
                tint: systemGlassTint,
                prominent: style == .full,
                enabled: systemGlassEnabled,
                forceSystemGlass: forceSystemGlass
            )
            // One restrained elevation shadow keeps hierarchy without visual noise.
            .shadow(
                color: primaryShadowColor,
                radius: primaryShadowRadius,
                x: 0,
                y: primaryShadowY
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
        if reduceTransparency {
            shape.fill(DS.solidSurface)
        } else if scrollPerformanceMode {
            shape
                .fill(DS.glassFill(0.085))
                .overlay { shape.fill(DS.glassTint).opacity(0.11) }
        } else if useFlatEffects {
            shape
                .fill(DS.glassFill(0.075))
                .overlay { shape.fill(DS.glassTint).opacity(isFlatStyle ? 0.18 : 0.12) }
                .overlay { shape.fill(DS.brandIridescent).blendMode(.screen).opacity(isFlatStyle ? 0.10 : 0.06) }
        } else if useLightEffects {
            shape
                .fill(DS.glassFill(0.095))
                .overlay { shape.fill(DS.glassDepth).opacity(0.12) }
                .overlay { shape.fill(DS.glassTint).opacity(0.24) }
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
    }

    private var primaryShadowColor: Color {
        if scrollPerformanceMode { return DS.shadow.opacity(0.06) }
        return DS.shadow.opacity(useFlatEffects ? 0.06 : (useLightEffects ? 0.12 : 0.20))
    }
    private var primaryShadowRadius: CGFloat {
        if scrollPerformanceMode { return 1.2 }
        return useFlatEffects ? 1.8 : (useLightEffects ? 4 : 10)
    }
    private var primaryShadowY: CGFloat {
        if scrollPerformanceMode { return 1 }
        return useFlatEffects ? 1 : (useLightEffects ? 2 : 5)
    }
    private func fullModeBackground(shape: RoundedRectangle) -> some View {
        shape
            .fill(DS.glass)
            .overlay { shape.fill(DS.glassDepth).opacity(0.22) }
            .overlay { shape.fill(DS.glassTint).opacity(0.46) }
            .overlay {
                shape
                    .fill(DS.brandIridescent)
                    .opacity(0.18)
                    .blendMode(.screen)
            }
            .overlay {
                shape
                    .fill(DS.sheen)
                    .opacity(0.24)
                    .blendMode(.screen)
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

// =======================================================
// MARK: - Buttons (cleaner pills + better pressed/disabled)
// =======================================================
struct LippiButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive, ghost }
    var kind: Kind = .primary
    var compact: Bool = false
    var allowsMultiline: Bool = false
    var forceSystemGlass: Bool = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.lippiIsScrolling) private var isScrolling

    private var simplifiedEffects: Bool { DS.performanceEffectsReduced || reduceTransparency || isScrolling }
    private var scrollingEffects: Bool { isScrolling }
    private var systemGlassEnabled: Bool { forceSystemGlass || !simplifiedEffects }
    private var usesSystemGlass: Bool {
        if #available(iOS 26.0, *) {
            return systemGlassEnabled && (forceSystemGlass || DS.systemGlassEffectsEnabled)
        }
        return false
    }
    private var systemGlassTint: Color? {
        switch kind {
        case .primary:
            return DS.accent.opacity(0.18)
        case .secondary:
            return DS.accent.opacity(0.09)
        case .destructive:
            return Color.red.opacity(0.12)
        case .ghost:
            return nil
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        return configuration.label
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .modifier(LippiButtonLabelLayoutModifier(allowsMultiline: allowsMultiline))
            .padding(.horizontal, compact ? 14 : 18)
            .padding(.vertical, compact ? 10 : 12)
            .frame(minHeight: compact ? 44 : 48)
            .background(background(pressed: pressed))
            .overlay(borderOverlay(pressed: pressed))
            .overlay(sheenOverlay(pressed: pressed))
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .opacity(isEnabled ? 1.0 : disabledOpacity)
            .saturation(isEnabled ? 1.0 : 0.86)
            .brightness(isEnabled ? (pressed && !simplifiedEffects ? 0.018 : 0) : -0.02)
            .lippiSystemGlass(
                in: Capsule(style: .continuous),
                tint: systemGlassTint,
                interactive: true,
                enabled: systemGlassEnabled,
                forceSystemGlass: forceSystemGlass
            )
            .offset(y: reduceMotion ? 0 : (pressed ? 0.7 : 0))
            .scaleEffect(reduceMotion ? 1 : (pressed ? DS.pressScale : 1))
            .shadow(
                color: shadowColor(pressed: pressed),
                radius: shadowRadius(pressed: pressed),
                x: 0,
                y: shadowY(pressed: pressed)
            )
            .animation((reduceMotion || scrollingEffects) ? nil : DS.motionPress, value: pressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                if newValue, isEnabled { DS.hapticSoft() }
            }
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        if reduceTransparency {
            switch kind {
            case .primary:
                Capsule().fill(DS.brand)
            case .secondary, .ghost:
                Capsule().fill(DS.solidSurface)
            case .destructive:
                Capsule().fill(
                    Color(
                        dynamicDark: 0x5A1A22,
                        light: 0xFFF0F1,
                        darkAlpha: 0.98,
                        lightAlpha: 0.98
                    )
                )
            }
        } else if usesSystemGlass {
            switch kind {
            case .primary:
                Capsule().fill(DS.accent.opacity(pressed ? 0.20 : 0.14))
            case .secondary:
                Capsule().fill(DS.glassFill(pressed ? 0.08 : 0.035))
            case .destructive:
                Capsule().fill(Color.red.opacity(pressed ? 0.18 : 0.11))
            case .ghost:
                Capsule().fill(Color.clear)
            }
        } else {
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
    }

    private func borderOverlay(pressed: Bool) -> some View {
        Capsule()
            .strokeBorder(borderColor(pressed: pressed), lineWidth: 1)
            .overlay(
                Group {
                    if !simplifiedEffects && !usesSystemGlass {
                        Capsule()
                            .strokeBorder(DS.glassStroke(pressed ? 0.22 : 0.10), lineWidth: 1)
                            .padding(1)
                    }
                }
            )
    }

    private func sheenOverlay(pressed: Bool) -> some View {
        Group {
            if !simplifiedEffects && !usesSystemGlass {
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
        if scrollingEffects { return .clear }
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

    private func shadowRadius(pressed: Bool) -> CGFloat {
        if scrollingEffects { return 0 }
        if pressed { return 3 }
        switch kind {
        case .primary:
            return simplifiedEffects ? 3 : 8
        case .secondary, .destructive:
            return simplifiedEffects ? 1.5 : 5
        case .ghost:
            return 0
        }
    }

    private func shadowY(pressed: Bool) -> CGFloat {
        if scrollingEffects { return 0 }
        if pressed { return 1 }
        switch kind {
        case .primary:
            return simplifiedEffects ? 2 : 4
        case .secondary, .destructive:
            return simplifiedEffects ? 1 : 2
        case .ghost:
            return 0
        }
    }
}

private struct LippiButtonLabelLayoutModifier: ViewModifier {
    let allowsMultiline: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if allowsMultiline {
            content
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            content.singleLine()
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
    @Environment(\.lippiIsScrolling) private var isScrolling

    // Тюнинг производительности
    private let globalBlurCap: CGFloat = 28
    private let blobEdgeSoftness: CGFloat = 0.72

    // In Simulator/Low Power/thermal pressure we keep the look, but stop live redraws.
    private var reducedEffects: Bool { DS.performanceEffectsReduced || isScrolling }
    private var targetFPS: Double { DS.preferredFramesPerSecond >= 120 ? 24 : 18 }
    private var effectiveFPS: Double { reducedEffects ? 8 : targetFPS }
    private var enableGlowBlend: Bool { !reducedEffects && !reduceMotion } // plusLighter дорогой при скролле

    var body: some View {
        ZStack {
            DS.bgBase

            if reduceMotion || reducedEffects {
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
                        let blurBase = m * 0.024
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
            .opacity(scheme == .dark ? (reducedEffects ? 0.38 : 0.55) : (reducedEffects ? 0.30 : 0.42))
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

        if reducedEffects || reduceMotion {
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
