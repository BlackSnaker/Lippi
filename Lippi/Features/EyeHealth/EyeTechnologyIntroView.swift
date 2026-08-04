import SwiftUI

private enum EyeTechnologyIntroPage: Int, CaseIterable, Identifiable {
    case welcome
    case trueDepth
    case privateAnalysis
    case adaptiveCare

    var id: Int { rawValue }

    var icon: String {
        switch self {
        case .welcome: return "eye.circle.fill"
        case .trueDepth: return "viewfinder.circle.fill"
        case .privateAnalysis: return "lock.shield.fill"
        case .adaptiveCare: return "sparkles"
        }
    }

    var accent: Color {
        switch self {
        case .welcome: return Color(hex: 0x64D2FF)
        case .trueDepth: return Color(hex: 0x5AC8FA)
        case .privateAnalysis: return Color(hex: 0x30D158)
        case .adaptiveCare: return Color(hex: 0xBF5AF2)
        }
    }
}

struct EyeTechnologyIntroView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage(L10n.storageKey) private var langRaw = AppLang.fallback.rawValue
    @State private var selectedPage = EyeTechnologyIntroPage.welcome.rawValue

    private var lang: AppLang { L10n.lang(from: langRaw) }
    private func s(_ key: String) -> String { L10n.tr(key, lang) }
    private var currentPage: EyeTechnologyIntroPage {
        EyeTechnologyIntroPage(rawValue: selectedPage) ?? .welcome
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppBackdrop(renderMode: .force)

                ambientLight(for: currentPage)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    header
                    pageDeck(height: proxy.size.height)
                    bottomControls
                }
                .padding(.top, max(proxy.safeAreaInsets.top, 8))
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 10))
            }
        }
        .interactiveDismissDisabled()
        .onAppear { DS.hapticSoft() }
    }

    private func ambientLight(for page: EyeTechnologyIntroPage) -> some View {
        ZStack {
            RadialGradient(
                colors: [page.accent.opacity(0.22), .clear],
                center: UnitPoint(x: 0.18, y: 0.16),
                startRadius: 0,
                endRadius: 330
            )
            RadialGradient(
                colors: [Color(hex: 0xBF5AF2).opacity(0.13), .clear],
                center: UnitPoint(x: 0.86, y: 0.82),
                startRadius: 0,
                endRadius: 360
            )
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.7), value: selectedPage)
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Image(safeSystemName: "eye.fill", fallback: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(currentPage.accent)
                    .frame(width: 32, height: 32)
                    .background(currentPage.accent.opacity(0.13), in: Circle())

                Text(s("eye.intro.eyebrow"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DS.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .padding(.vertical, 6)
            .background(DS.glassFill(0.07), in: Capsule())
            .overlay(Capsule().stroke(DS.glassStroke(0.12), lineWidth: 1))
            .lippiSystemGlass(
                in: Capsule(),
                tint: currentPage.accent.opacity(0.08),
                forceSystemGlass: true
            )

            Spacer(minLength: 8)

            Button(action: finish) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(DS.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .background(DS.glassFill(0.08), in: Circle())
            .overlay(Circle().stroke(DS.glassStroke(0.13), lineWidth: 1))
            .lippiSystemGlass(
                in: Circle(),
                tint: Color.white.opacity(0.04),
                interactive: true,
                forceSystemGlass: true
            )
            .accessibilityLabel(Text(s("eye.intro.close")))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func pageDeck(height: CGFloat) -> some View {
        TabView(selection: $selectedPage) {
            ForEach(EyeTechnologyIntroPage.allCases) { page in
                introPage(page, availableHeight: height)
                    .tag(page.rawValue)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.10), value: selectedPage)
        .onChange(of: selectedPage) { _, _ in DS.hapticSoft() }
    }

    private func introPage(
        _ page: EyeTechnologyIntroPage,
        availableHeight: CGFloat
    ) -> some View {
        ScrollView {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 18 : 22) {
                EyeTechnologyVisual(
                    page: page,
                    reduceMotion: reduceMotion,
                    reduceTransparency: reduceTransparency
                )
                .frame(
                    width: min(availableHeight * 0.32, 270),
                    height: min(availableHeight * 0.32, 270)
                )
                .padding(.top, 4)

                VStack(spacing: 10) {
                    Text(title(for: page))
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle(for: page))
                        .font(.title3.weight(.medium))
                        .foregroundStyle(page.accent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(body(for: page))
                        .font(.body)
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }

                benefitCard(for: page)
            }
            .frame(maxWidth: 620)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private func benefitCard(for page: EyeTechnologyIntroPage) -> some View {
        let benefits = benefits(for: page)
        return VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                HStack(alignment: .top, spacing: 12) {
                    Image(safeSystemName: benefit.icon, fallback: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(page.accent)
                        .frame(width: 34, height: 34)
                        .background(page.accent.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DS.textPrimary)
                        Text(benefit.detail)
                            .font(.caption)
                            .foregroundStyle(DS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)

                if index < benefits.count - 1 {
                    Divider().overlay(DS.glassStroke(0.08))
                }
            }
        }
        .padding(.horizontal, 14)
        .background(
            DS.glassFill(reduceTransparency ? 0.13 : 0.065),
            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(DS.glassStroke(0.13), lineWidth: 1)
        )
        .lippiSystemGlass(
            in: RoundedRectangle(cornerRadius: 25, style: .continuous),
            tint: page.accent.opacity(0.07),
            forceSystemGlass: true
        )
    }

    private var bottomControls: some View {
        VStack(spacing: 13) {
            HStack(spacing: 7) {
                ForEach(EyeTechnologyIntroPage.allCases) { page in
                    Capsule()
                        .fill(page.rawValue == selectedPage ? currentPage.accent : DS.glassStroke(0.16))
                        .frame(width: page.rawValue == selectedPage ? 28 : 7, height: 7)
                        .animation(reduceMotion ? nil : .spring(duration: 0.42, bounce: 0.15), value: selectedPage)
                }
            }
            .accessibilityHidden(true)

            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(
                        currentPage == .adaptiveCare
                            ? s("eye.intro.finish")
                            : s("eye.intro.continue")
                    )
                    Image(systemName: currentPage == .adaptiveCare ? "checkmark" : "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(LippiButtonStyle(kind: .primary, forceSystemGlass: true))
        }
        .frame(maxWidth: 620)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.clear, DS.backdropBase.opacity(0.82), DS.backdropBase],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private func advance() {
        guard selectedPage < EyeTechnologyIntroPage.allCases.count - 1 else {
            finish()
            return
        }
        withAnimation(reduceMotion ? nil : .spring(duration: 0.52, bounce: 0.10)) {
            selectedPage += 1
        }
    }

    private func finish() {
        DS.hapticSoft()
        onFinish()
    }

    private func title(for page: EyeTechnologyIntroPage) -> String {
        s("eye.intro.page\(page.rawValue + 1).title")
    }

    private func subtitle(for page: EyeTechnologyIntroPage) -> String {
        s("eye.intro.page\(page.rawValue + 1).subtitle")
    }

    private func body(for page: EyeTechnologyIntroPage) -> String {
        s("eye.intro.page\(page.rawValue + 1).body")
    }

    private func benefits(
        for page: EyeTechnologyIntroPage
    ) -> [(icon: String, title: String, detail: String)] {
        switch page {
        case .welcome:
            return [
                ("eye.fill", s("eye.intro.welcome.fact1.title"), s("eye.intro.welcome.fact1.body")),
                ("timer", s("eye.intro.welcome.fact2.title"), s("eye.intro.welcome.fact2.body"))
            ]
        case .trueDepth:
            return [
                ("ruler.fill", s("eye.intro.depth.fact1.title"), s("eye.intro.depth.fact1.body")),
                ("viewfinder", s("eye.intro.depth.fact2.title"), s("eye.intro.depth.fact2.body"))
            ]
        case .privateAnalysis:
            return [
                ("iphone", s("eye.intro.private.fact1.title"), s("eye.intro.private.fact1.body")),
                ("person.crop.circle.badge.xmark", s("eye.intro.private.fact2.title"), s("eye.intro.private.fact2.body"))
            ]
        case .adaptiveCare:
            return [
                ("brain.head.profile", s("eye.intro.care.fact1.title"), s("eye.intro.care.fact1.body")),
                ("figure.mind.and.body", s("eye.intro.care.fact2.title"), s("eye.intro.care.fact2.body"))
            ]
        }
    }
}

private struct EyeTechnologyVisual: View {
    let page: EyeTechnologyIntroPage
    let reduceMotion: Bool
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
                visual(
                    at: timeline.date.timeIntervalSinceReferenceDate,
                    canvasSize: proxy.size
                )
            }
        }
        .accessibilityHidden(true)
    }

    private func visual(at elapsed: TimeInterval, canvasSize: CGSize) -> some View {
        let slowRotation = reduceMotion ? 0 : elapsed.truncatingRemainder(dividingBy: 14) / 14 * 360
        let pulse = reduceMotion ? 0.5 : (sin(elapsed * 2.0) + 1) / 2

        return ZStack {
            Circle()
                .fill(page.accent.opacity(reduceTransparency ? 0.12 : 0.18))
                .blur(radius: reduceTransparency ? 0 : 28)
                .scaleEffect(0.88 + pulse * 0.08)

            Circle()
                .stroke(page.accent.opacity(0.13), lineWidth: 18)
                .padding(18)
                .blur(radius: reduceTransparency ? 0 : 13)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            page.accent.opacity(0.20),
                            page.accent,
                            Color(hex: 0xBF5AF2),
                            Color(hex: 0x64D2FF),
                            page.accent.opacity(0.20)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [24, 12])
                )
                .padding(22)
                .rotationEffect(.degrees(slowRotation))

            Circle()
                .fill(DS.glassFill(reduceTransparency ? 0.16 : 0.085))
                .padding(43)
                .overlay(
                    Circle()
                        .stroke(DS.glassStroke(0.18), lineWidth: 1)
                        .padding(43)
                )
                .lippiSystemGlass(
                    in: Circle(),
                    tint: page.accent.opacity(0.11),
                    forceSystemGlass: true
                )

            pageGlyph(elapsed: elapsed, pulse: pulse, canvasSize: canvasSize)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.55), value: page)
    }

    @ViewBuilder
    private func pageGlyph(
        elapsed: TimeInterval,
        pulse: Double,
        canvasSize: CGSize
    ) -> some View {
        switch page {
        case .welcome:
            ZStack {
                Image(safeSystemName: "eye.fill", fallback: "eye")
                    .font(.system(size: canvasSize.width * 0.28, weight: .medium, design: .rounded))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(page.accent)
                Circle()
                    .fill(.white)
                    .frame(width: 13, height: 13)
                    .shadow(color: page.accent, radius: 12)
                    .offset(x: CGFloat(sin(elapsed * 1.25)) * canvasSize.width * 0.08)
            }

        case .trueDepth:
            TrueDepthEyesAnimation(
                elapsed: elapsed,
                reduceMotion: reduceMotion,
                reduceTransparency: reduceTransparency
            )
            .frame(width: canvasSize.width * 0.94, height: canvasSize.height * 0.78)

        case .privateAnalysis:
            ZStack {
                Image(safeSystemName: "lock.shield.fill", fallback: "lock.fill")
                    .font(.system(size: 72, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(page.accent)

                ForEach(0 ..< 6, id: \.self) { index in
                    let angle = Double(index) / 6 * Double.pi * 2 + elapsed * 0.34
                    Circle()
                        .fill(index.isMultiple(of: 2) ? page.accent : Color(hex: 0x64D2FF))
                        .frame(width: 6, height: 6)
                        .position(
                            x: canvasSize.width / 2 + cos(angle) * canvasSize.width * 0.31,
                            y: canvasSize.height / 2 + sin(angle) * canvasSize.height * 0.31
                        )
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)

        case .adaptiveCare:
            ZStack {
                ForEach(0 ..< 3, id: \.self) { index in
                    let angle = Double(index) / 3 * Double.pi * 2 - Double.pi / 2
                    let icons = ["eye.fill", "timer", "heart.fill"]
                    Image(safeSystemName: icons[index], fallback: "circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(index == 0 ? Color(hex: 0x64D2FF) : index == 1 ? Color(hex: 0xFF9F0A) : Color(hex: 0x30D158))
                        .frame(width: 48, height: 48)
                        .background(DS.glassFill(0.11), in: Circle())
                        .overlay(Circle().stroke(DS.glassStroke(0.14), lineWidth: 1))
                        .position(
                            x: canvasSize.width / 2 + cos(angle) * canvasSize.width * 0.31,
                            y: canvasSize.height / 2 + sin(angle) * canvasSize.height * 0.31
                        )
                }

                Image(safeSystemName: "sparkles", fallback: "brain.head.profile")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(page.accent)
                    .scaleEffect(0.96 + pulse * 0.08)
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
    }

}

/// An abstract binocular depth field: only the eyes and anonymous spatial
/// samples are shown. No portrait, facial outline, or identity-bearing image is
/// created. Canvas keeps the animation crisp without hundreds of SwiftUI views.
private struct TrueDepthEyesAnimation: View {
    private struct DepthPoint {
        let x: CGFloat
        let y: CGFloat
        let depth: CGFloat
        let seed: CGFloat
    }

    let elapsed: TimeInterval
    let reduceMotion: Bool
    let reduceTransparency: Bool

    private static let points: [DepthPoint] = makePointField()

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                eyesAura(elapsed: elapsed)

                Canvas(
                    opaque: false,
                    colorMode: .extendedLinear,
                    rendersAsynchronously: false
                ) { context, size in
                    drawDepthField(in: &context, size: size, elapsed: elapsed)
                    drawEyes(in: &context, size: size, elapsed: elapsed)
                    drawScan(in: &context, size: size, elapsed: elapsed)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .accessibilityHidden(true)
    }

    private func eyesAura(elapsed: TimeInterval) -> some View {
        let pulse = reduceMotion ? 0.5 : (sin(elapsed * 1.45) + 1) / 2

        return ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x64D2FF).opacity(reduceTransparency ? 0.04 : 0.13),
                            Color(hex: 0x5E5CE6).opacity(reduceTransparency ? 0.03 : 0.10),
                            Color(hex: 0xBF5AF2).opacity(reduceTransparency ? 0.03 : 0.09)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 238, height: 98)
                .blur(radius: reduceTransparency ? 0 : 28)
                .scaleEffect(0.98 + pulse * 0.035)

            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x64D2FF).opacity(0.18),
                            Color.white.opacity(0.08),
                            Color(hex: 0xBF5AF2).opacity(0.16)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 10
                )
                .frame(width: 250, height: 112)
                .blur(radius: reduceTransparency ? 0 : 13)
        }
    }

    private func drawDepthField(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        let scanPhase = reduceMotion
            ? 0.5
            : CGFloat(elapsed.truncatingRemainder(dividingBy: 3.4) / 3.4)
        let scanX = 0.08 + scanPhase * 0.84
        let breath = reduceMotion ? 0 : CGFloat(sin(elapsed * 0.74)) * size.height * 0.004

        for point in Self.points {
            let distanceToScan = abs(point.x - scanX)
            let scanGlow = max(0, 1 - distanceToScan / 0.085)
            let twinkle = reduceMotion
                ? 0.72
                : 0.58 + 0.42 * CGFloat(sin(elapsed * (1.3 + Double(point.seed)) + Double(point.seed * 11)))
            let diameter = 1.0 + point.depth * 2.25 + scanGlow * 1.15
            let position = CGPoint(
                x: point.x * size.width,
                y: point.y * size.height + breath * (0.45 + point.depth)
            )
            let rect = CGRect(
                x: position.x - diameter / 2,
                y: position.y - diameter / 2,
                width: diameter,
                height: diameter
            )
            let color = depthColor(for: point.depth)
                .opacity(0.19 + point.depth * 0.48 + scanGlow * 0.28)

            context.fill(
                Path(ellipseIn: rect),
                with: .color(color.opacity(twinkle))
            )
        }

        drawDepthContours(in: &context, size: size, elapsed: elapsed)
    }

    private func drawDepthContours(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        let drift = reduceMotion ? 0 : CGFloat(sin(elapsed * 0.56)) * size.width * 0.008

        for index in 0 ..< 3 {
            let inset = CGFloat(index) * size.width * 0.035
            let rect = CGRect(
                x: size.width * 0.10 + inset + drift,
                y: size.height * (0.30 + CGFloat(index) * 0.035),
                width: size.width * 0.80 - inset * 2,
                height: size.height * (0.40 - CGFloat(index) * 0.07)
            )
            context.stroke(
                Path(roundedRect: rect, cornerRadius: rect.height / 2),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(hex: 0x64D2FF).opacity(0.20 - Double(index) * 0.035),
                        Color.white.opacity(0.08),
                        Color(hex: 0xBF5AF2).opacity(0.16 - Double(index) * 0.025)
                    ]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.midY)
                ),
                lineWidth: index == 0 ? 0.9 : 0.55
            )
        }
    }

    private func drawEyes(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        let openness = eyeOpenness(at: elapsed)
        let gazeX = reduceMotion ? 0 : CGFloat(sin(elapsed * 0.48)) * size.width * 0.013
        let gazeY = reduceMotion ? 0 : CGFloat(sin(elapsed * 0.33 + 0.8)) * size.height * 0.010
        let centers = [
            CGPoint(x: size.width * 0.32, y: size.height * 0.50),
            CGPoint(x: size.width * 0.68, y: size.height * 0.50)
        ]

        for (index, center) in centers.enumerated() {
            drawEye(
                in: &context,
                center: center,
                size: size,
                openness: openness,
                gaze: CGPoint(x: gazeX, y: gazeY),
                accentShift: index
            )
        }
    }

    private func drawEye(
        in context: inout GraphicsContext,
        center: CGPoint,
        size: CGSize,
        openness: CGFloat,
        gaze: CGPoint,
        accentShift: Int
    ) {
        let width = size.width * 0.245
        let fullHeight = size.height * 0.145
        let height = max(1.4, fullHeight * openness)
        let eye = eyePath(center: center, width: width, height: height)

        if openness > 0.14 {
            context.fill(
                eye,
                with: .linearGradient(
                    Gradient(colors: [
                        Color.white.opacity(reduceTransparency ? 0.18 : 0.34),
                        Color(hex: 0xDFF8FF).opacity(reduceTransparency ? 0.10 : 0.24),
                        Color(hex: 0x8E8CF5).opacity(0.08)
                    ]),
                    startPoint: CGPoint(x: center.x, y: center.y - height / 2),
                    endPoint: CGPoint(x: center.x, y: center.y + height / 2)
                )
            )

            let irisCenter = CGPoint(
                x: center.x + gaze.x,
                y: center.y + gaze.y
            )
            let irisRadius = min(width * 0.20, fullHeight * 0.38) * min(1, openness * 1.45)
            let irisRect = CGRect(
                x: irisCenter.x - irisRadius,
                y: irisCenter.y - irisRadius,
                width: irisRadius * 2,
                height: irisRadius * 2
            )
            let irisColors: [Color] = accentShift == 0
                ? [
                    Color(hex: 0xB9FBFF),
                    Color(hex: 0x64D2FF),
                    Color(hex: 0x0A84FF),
                    Color(hex: 0x5E5CE6)
                ]
                : [
                    Color(hex: 0xE2D7FF),
                    Color(hex: 0x64D2FF),
                    Color(hex: 0x5E5CE6),
                    Color(hex: 0xBF5AF2)
                ]

            context.fill(
                Path(ellipseIn: irisRect),
                with: .radialGradient(
                    Gradient(colors: irisColors),
                    center: irisCenter,
                    startRadius: 0,
                    endRadius: irisRadius
                )
            )

            let pupilRadius = irisRadius * 0.34
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: irisCenter.x - pupilRadius,
                        y: irisCenter.y - pupilRadius,
                        width: pupilRadius * 2,
                        height: pupilRadius * 2
                    )
                ),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(hex: 0x06121F).opacity(0.98),
                        Color(hex: 0x10234B).opacity(0.96)
                    ]),
                    center: irisCenter,
                    startRadius: 0,
                    endRadius: pupilRadius
                )
            )

            let highlightRadius = max(1.4, irisRadius * 0.15)
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: irisCenter.x - irisRadius * 0.30,
                        y: irisCenter.y - irisRadius * 0.38,
                        width: highlightRadius * 2,
                        height: highlightRadius * 2
                    )
                ),
                with: .color(Color.white.opacity(0.92))
            )
        }

        context.stroke(
            eye,
            with: .linearGradient(
                Gradient(colors: [
                    Color(hex: 0x64D2FF).opacity(0.94),
                    Color.white.opacity(0.78),
                    Color(hex: 0xBF5AF2).opacity(0.88)
                ]),
                startPoint: CGPoint(x: center.x - width / 2, y: center.y),
                endPoint: CGPoint(x: center.x + width / 2, y: center.y)
            ),
            style: StrokeStyle(
                lineWidth: openness < 0.22 ? 1.8 : 1.35,
                lineCap: .round,
                lineJoin: .round
            )
        )

        if openness > 0.36 {
            let upperLid = upperLidPath(
                center: CGPoint(x: center.x, y: center.y - fullHeight * 0.06),
                width: width * 1.03,
                height: fullHeight * 0.98
            )
            context.stroke(
                upperLid,
                with: .color(Color.white.opacity(0.24)),
                style: StrokeStyle(lineWidth: 0.65, lineCap: .round)
            )
        }
    }

    private func drawScan(
        in context: inout GraphicsContext,
        size: CGSize,
        elapsed: TimeInterval
    ) {
        let phase = reduceMotion
            ? 0.5
            : CGFloat(elapsed.truncatingRemainder(dividingBy: 3.4) / 3.4)
        let x = size.width * (0.08 + phase * 0.84)
        let top = size.height * 0.30
        let bottom = size.height * 0.70

        context.drawLayer { layer in
            if !reduceTransparency {
                layer.addFilter(.blur(radius: 7))
            }
            let glowRect = CGRect(
                x: x - size.width * 0.035,
                y: top,
                width: size.width * 0.07,
                height: bottom - top
            )
            layer.fill(
                Path(roundedRect: glowRect, cornerRadius: glowRect.width / 2),
                with: .linearGradient(
                    Gradient(colors: [
                        Color.clear,
                        Color(hex: 0x64D2FF).opacity(reduceTransparency ? 0.10 : 0.28),
                        Color.white.opacity(reduceTransparency ? 0.10 : 0.38),
                        Color(hex: 0xBF5AF2).opacity(reduceTransparency ? 0.08 : 0.22),
                        Color.clear
                    ]),
                    startPoint: CGPoint(x: x, y: top),
                    endPoint: CGPoint(x: x, y: bottom)
                )
            )
        }

        var scanLine = Path()
        scanLine.move(to: CGPoint(x: x, y: top))
        scanLine.addCurve(
            to: CGPoint(x: x, y: bottom),
            control1: CGPoint(x: x + size.width * 0.018, y: size.height * 0.42),
            control2: CGPoint(x: x - size.width * 0.018, y: size.height * 0.58)
        )
        context.stroke(
            scanLine,
            with: .linearGradient(
                Gradient(colors: [
                    Color.clear,
                    Color(hex: 0x64D2FF).opacity(0.82),
                    Color.white.opacity(0.90),
                    Color(hex: 0xBF5AF2).opacity(0.66),
                    Color.clear
                ]),
                startPoint: CGPoint(x: x, y: top),
                endPoint: CGPoint(x: x, y: bottom)
            ),
            style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
        )
    }

    private func eyeOpenness(at elapsed: TimeInterval) -> CGFloat {
        guard !reduceMotion else { return 1 }

        let cycle = elapsed.truncatingRemainder(dividingBy: 5.6)
        let blinkCenter = 5.08
        let distance = abs(cycle - blinkCenter)
        guard distance < 0.14 else { return 1 }

        let normalized = CGFloat(distance / 0.14)
        return 0.06 + normalized * 0.94
    }

    private func eyePath(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat
    ) -> Path {
        var path = Path()
        let left = CGPoint(x: center.x - width / 2, y: center.y)
        let right = CGPoint(x: center.x + width / 2, y: center.y)

        path.move(to: left)
        path.addCurve(
            to: right,
            control1: CGPoint(
                x: center.x - width * 0.23,
                y: center.y - height * 0.62
            ),
            control2: CGPoint(
                x: center.x + width * 0.23,
                y: center.y - height * 0.62
            )
        )
        path.addCurve(
            to: left,
            control1: CGPoint(
                x: center.x + width * 0.23,
                y: center.y + height * 0.62
            ),
            control2: CGPoint(
                x: center.x - width * 0.23,
                y: center.y + height * 0.62
            )
        )
        path.closeSubpath()
        return path
    }

    private func upperLidPath(
        center: CGPoint,
        width: CGFloat,
        height: CGFloat
    ) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x - width / 2, y: center.y))
        path.addCurve(
            to: CGPoint(x: center.x + width / 2, y: center.y),
            control1: CGPoint(
                x: center.x - width * 0.22,
                y: center.y - height * 0.58
            ),
            control2: CGPoint(
                x: center.x + width * 0.22,
                y: center.y - height * 0.58
            )
        )
        return path
    }

    private func depthColor(for depth: CGFloat) -> Color {
        switch depth {
        case ..<0.30:
            return Color(hex: 0x5E5CE6)
        case ..<0.62:
            return Color(hex: 0x64D2FF)
        case ..<0.82:
            return Color(hex: 0x7D7AFF)
        default:
            return Color(hex: 0xBF5AF2)
        }
    }

    private static func makePointField() -> [DepthPoint] {
        (0 ..< 340).map { index in
            let seed = CGFloat(index)
            let u = pseudoRandom(seed * 12.9898 + 1.17)
            let v = pseudoRandom(seed * 78.233 + 7.31)
            let x = 0.08 + u * 0.84
            let normalizedX = (x - 0.5) / 0.42
            let fieldShape = sqrt(max(0, 1 - normalizedX * normalizedX))
            let halfHeight = 0.075 + fieldShape * 0.16
            let centerY = 0.5 + sin((x - 0.5) * .pi) * 0.012
            let y = centerY + (v - 0.5) * 2 * halfHeight

            let leftEye = gaussianDistance(
                x: x,
                y: y,
                centerX: 0.32,
                centerY: 0.5,
                spreadX: 0.15,
                spreadY: 0.115
            )
            let rightEye = gaussianDistance(
                x: x,
                y: y,
                centerX: 0.68,
                centerY: 0.5,
                spreadX: 0.15,
                spreadY: 0.115
            )
            let depth = min(1, 0.18 + max(leftEye, rightEye) * 0.72 + pseudoRandom(seed * 5.73) * 0.10)

            return DepthPoint(
                x: x,
                y: y,
                depth: depth,
                seed: pseudoRandom(seed * 3.41 + 2.08)
            )
        }
    }

    private static func pseudoRandom(_ value: CGFloat) -> CGFloat {
        let raw = sin(value) * 43_758.5453
        return raw - floor(raw)
    }

    private static func gaussianDistance(
        x: CGFloat,
        y: CGFloat,
        centerX: CGFloat,
        centerY: CGFloat,
        spreadX: CGFloat,
        spreadY: CGFloat
    ) -> CGFloat {
        let dx = (x - centerX) / spreadX
        let dy = (y - centerY) / spreadY
        return exp(-(dx * dx + dy * dy))
    }
}
